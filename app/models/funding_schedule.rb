class FundingSchedule < ApplicationRecord
  has_paper_trail
  belongs_to :user
  has_many :expenses, dependent: :restrict_with_error
  has_many :funding_events, dependent: :destroy

  CADENCES = %w[weekly biweekly semimonthly monthly].freeze

  validates :name, presence: true, length: { maximum: 100 }
  validates :cadence, inclusion: { in: CADENCES, message: 'must be selected' }
  validates :start_date, presence: true
  validates :second_day_of_month,
            presence: true,
            inclusion: { in: 1..31, message: 'must be a day from 1 to 31' },
            if: :semimonthly?
  validates :second_day_of_month, absence: true, unless: :semimonthly?
  validate :second_day_differs_from_start_day, if: :semimonthly?

  def semimonthly? = cadence == 'semimonthly'

  # Find-or-creates a FundingEvent for every occurrence between the last
  # materialized event (or start_date) through end_date. Idempotent.
  def materialize_events_through(end_date:)
    return [] if start_date.blank? || cadence.blank?

    last = funding_events.maximum(:occurs_on)
    cursor = last ? advance(last) : start_date
    events = []
    while cursor && cursor <= end_date
      events << funding_events.create_or_find_by!(occurs_on: cursor)
      cursor = advance(cursor)
    end
    events
  end

  # Returns the next `count` dates this schedule fires on or after `after`.
  def next_occurrences(count: 3, after: Date.current)
    return [] if start_date.blank? || cadence.blank?

    cursor = first_occurrence_on_or_after(after)
    Array.new(count) do
      occurrence = cursor
      cursor = advance(cursor)
      occurrence
    end
  end

  private

  def second_day_differs_from_start_day
    return if second_day_of_month.blank? || start_date.blank?
    return if start_date.day != second_day_of_month

    errors.add(:second_day_of_month, "must be different from the first occurrence's day")
  end

  def first_occurrence_on_or_after(target)
    cursor = start_date
    cursor = advance(cursor) while cursor < target
    cursor
  end

  def advance(date)
    case cadence
    when 'weekly'      then date + 7
    when 'biweekly'    then date + 14
    when 'monthly'     then advance_monthly(date)
    when 'semimonthly' then advance_semimonthly(date)
    end
  end

  def advance_monthly(date)
    next_month = date >> 1
    clamp_day(next_month.year, next_month.month, start_date.day)
  end

  def advance_semimonthly(date)
    d1, d2 = [ start_date.day, second_day_of_month ].sort

    first = clamp_day(date.year, date.month, d1)
    return first if date < first

    second = clamp_day(date.year, date.month, d2)
    return second if date < second

    next_month = date >> 1
    clamp_day(next_month.year, next_month.month, d1)
  end

  def clamp_day(year, month, day)
    last = Date.new(year, month, -1)
    Date.new(year, month, [ day, last.day ].min)
  end
end
