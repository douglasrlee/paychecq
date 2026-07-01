class Goal < ApplicationRecord
  has_paper_trail
  belongs_to :user
  belongs_to :funding_schedule
  has_many :allocations, dependent: :destroy

  CADENCES = %w[monthly quarterly semiannual yearly].freeze

  validates :name, presence: true, length: { maximum: 100 }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :cadence, inclusion: { in: CADENCES, message: 'must be selected' }
  validates :due_on, presence: true
  validate :funding_schedule_belongs_to_user

  def next_due_on(after: Date.current)
    return nil if due_on.blank? || CADENCES.exclude?(cadence)

    cursor = due_on
    cursor = advance(cursor) while cursor < after
    cursor
  end

  # The due date to show and sort by — the next occurrence on or after today,
  # rolling forward the day after one passes, independent of payment. `due_on`
  # stays put as the anchor the user picked.
  def current_due_on(as_of: Date.current)
    next_due_on(after: as_of) || due_on
  end

  def bucket_balance
    allocations.where.not(funded_at: nil)
               .where('amount > spent_amount')
               .sum(Arel.sql('amount - spent_amount'))
  end

  # Off-track when the current cycle isn't fully funded yet and money is still
  # queued to catch it up. Pre-funded future cycles leave pending allocations
  # around, so "any pending allocation" no longer means off-track.
  def off_track?
    bucket_balance < amount && allocations.exists?(funded_at: nil)
  end

  def fully_funded?
    bucket_balance >= amount
  end

  # Per-paycheck contribution still needed: remaining-to-fund /
  # paychecks-until-next-due. Display-only. Money already in the bucket lowers
  # the remaining, so funding the goal (by paycheck or by hand) shrinks this
  # rate; a fully-funded bucket needs $0/paycheck.
  def per_paycheck_amount(as_of: Date.current)
    next_due = next_due_on(after: as_of)
    return amount unless next_due && funding_schedule

    remaining = amount - bucket_balance
    return 0 if remaining <= 0

    paychecks = funding_schedule.occurrence_count_between(after: as_of, through: next_due)
    paychecks = 1 if paychecks.zero?
    (remaining / paychecks).round(2)
  end

  # The due date `cycles` full cadence-cycles after `from`. The allocation
  # engine uses this to roll the funding horizon forward when pre-funding
  # future cycles. Clamps day-of-month like the rest of the cadence math.
  def advance_due(from, cycles)
    months = case cadence
             when 'monthly'    then 1
             when 'quarterly'  then 3
             when 'semiannual' then 6
             when 'yearly'     then 12
             end
    advance_months(from, cycles * months)
  end

  private

  def funding_schedule_belongs_to_user
    return if funding_schedule.blank? || user_id.blank?
    return if funding_schedule.user_id == user_id

    errors.add(:funding_schedule_id, 'must belong to you')
  end

  def advance(date)
    case cadence
    when 'monthly'    then advance_months(date, 1)
    when 'quarterly'  then advance_months(date, 3)
    when 'semiannual' then advance_months(date, 6)
    when 'yearly'     then advance_months(date, 12)
    end
  end

  def advance_months(date, months)
    next_date = date >> months
    clamp_day(next_date.year, next_date.month, due_on.day)
  end

  def clamp_day(year, month, day)
    last = Date.new(year, month, -1)
    Date.new(year, month, [ day, last.day ].min)
  end
end
