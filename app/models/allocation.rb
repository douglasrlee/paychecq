class Allocation < ApplicationRecord
  has_paper_trail
  belongs_to :funding_event
  belongs_to :expense, optional: true
  belongs_to :goal, optional: true
  belongs_to :spent_by_transaction, class_name: 'Transaction', optional: true

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
