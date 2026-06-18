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
  # Not used by the index in Phase 2 — kept for the allocation engine.
  def next_due_on(after: Date.current)
    return nil if due_on.blank? || CADENCES.exclude?(cadence)

    cursor = due_on
    cursor = advance(cursor) while cursor < after
    cursor
  end

  def past_due?
    due_on.present? && due_on < Date.current
  end

  # Sum of funded, unspent allocations — money sitting in the bucket
  # right now. A linked transaction marks its expense's allocations spent
  # via spent_at, removing them from this sum.
  def bucket_balance
    allocations.where.not(funded_at: nil).where(spent_at: nil).sum(:amount)
  end

  # An expense is off-track when any allocation has been proposed but not
  # yet funded (the balance hasn't caught up).
  def off_track?
    allocations.exists?(funded_at: nil)
  end

  # Roll due_on forward / backward by one cadence cycle. Called by the
  # expense linker when a transaction is linked (forward) or unlinked
  # (backward). Public surface so the service doesn't need to reach into
  # the private advance/recede helpers.
  def bump_due_forward!
    update!(due_on: advance(due_on))
  end

  def bump_due_backward!
    update!(due_on: recede(due_on))
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

  def recede(date)
    case cadence
    when 'monthly'    then recede_months(date, 1)
    when 'quarterly'  then recede_months(date, 3)
    when 'semiannual' then recede_months(date, 6)
    when 'yearly'     then recede_months(date, 12)
    end
  end

  def advance_months(date, months)
    next_date = date >> months
    clamp_day(next_date.year, next_date.month, due_on.day)
  end

  def recede_months(date, months)
    prev_date = date << months
    clamp_day(prev_date.year, prev_date.month, due_on.day)
  end

  def clamp_day(year, month, day)
    last = Date.new(year, month, -1)
    Date.new(year, month, [ day, last.day ].min)
  end
end
