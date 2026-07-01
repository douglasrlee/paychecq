class Expense < ApplicationRecord
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

  # Returns the next date this expense is due on or after `after`.
  def next_due_on(after: Date.current)
    return nil if due_on.blank? || CADENCES.exclude?(cadence)

    cursor = due_on
    cursor = advance(cursor) while cursor < after
    cursor
  end

  # The due date to show and sort by. Due dates are calendar-driven and
  # independent of payment: the next occurrence on or after today, rolling
  # forward the day after one passes. `due_on` itself stays put as the anchor
  # the user picked; this rolls it forward without mutating it (and without
  # day-of-month drift, since it always clamps from the pristine `due_on` day).
  def current_due_on(as_of: Date.current)
    next_due_on(after: as_of) || due_on
  end

  # Money sitting in the bucket right now: the unspent remainder of each
  # funded allocation. Most rows are either fully unspent (spent_amount = 0,
  # full amount available) or fully spent (spent_amount = amount, contributes
  # 0). The middle case — one allocation per linked transaction — can be
  # partially spent when a transaction's amount didn't divide cleanly; the
  # residual stays in the bucket here.
  def bucket_balance
    allocations.where.not(funded_at: nil)
               .where('amount > spent_amount')
               .sum(Arel.sql('amount - spent_amount'))
  end

  # An expense is off-track when the current cycle isn't fully funded yet and
  # there's still money queued (a pending allocation) to catch it up. Banking
  # future cycles ahead of time (the engine keeps pre-funding past a full
  # bucket) leaves pending allocations around, so "any pending allocation" can
  # no longer mean off-track — only an under-funded current cycle does.
  def off_track?
    allocations.exists?(funded_at: nil) && bucket_balance < amount
  end

  # True when the bucket has enough money to cover the expense's target.
  def fully_funded?
    bucket_balance >= amount
  end

  # Per-paycheck contribution still needed: remaining-to-fund /
  # paychecks-until-next-due. Display-only. Money already in the bucket lowers
  # the remaining, so funding the expense (by paycheck or by hand) shrinks this
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
    months = { 'monthly' => 1, 'quarterly' => 3, 'semiannual' => 6, 'yearly' => 12 }[cadence]
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
