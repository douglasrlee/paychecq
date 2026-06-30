class Allocation < ApplicationRecord
  has_paper_trail
  # Optional: a manual allocation (user funded a bucket directly) has no
  # funding_event. Auto allocations from the engine always set one.
  belongs_to :funding_event, optional: true
  belongs_to :expense, optional: true
  belongs_to :goal, optional: true
  belongs_to :spent_by_transaction, class_name: 'Transaction', optional: true
  has_many :allocation_spends, dependent: :delete_all

  # Manual allocations carry no funding_event. One per bucket, enforced by the
  # uniqueness validations below (scope: :funding_event_id, IS NULL here) and a
  # matching partial unique index.
  scope :manual, -> { where(funding_event_id: nil) }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :spent_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :spent_amount_within_amount
  validate :exactly_one_allocatable
  validates :expense_id, uniqueness: { scope: :funding_event_id }, allow_nil: true
  validates :goal_id, uniqueness: { scope: :funding_event_id }, allow_nil: true

  private

  def spent_amount_within_amount
    return if spent_amount.blank? || amount.blank?
    return if spent_amount <= amount

    errors.add(:spent_amount, 'cannot exceed amount')
  end

  def exactly_one_allocatable
    return if expense_id.present? ^ goal_id.present?

    errors.add(:base, 'must belong to exactly one of an expense or a goal')
  end
end
