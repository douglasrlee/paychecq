class FundingSchedule < ApplicationRecord
  has_paper_trail
  belongs_to :user

  CADENCES = %w[weekly biweekly semimonthly monthly].freeze

  validates :name, presence: true, length: { maximum: 100 }
  validates :cadence, inclusion: { in: CADENCES, message: 'must be selected' }
  validates :start_date, presence: true
  validates :second_day_of_month,
            presence: true,
            inclusion: { in: 1..31, message: 'must be a day from 1 to 31' },
            if: :semimonthly?
  validates :second_day_of_month, absence: true, unless: :semimonthly?

  def semimonthly? = cadence == 'semimonthly'

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
