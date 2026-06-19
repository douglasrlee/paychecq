class Allocation < ApplicationRecord
  has_paper_trail
  belongs_to :funding_event
  belongs_to :expense
  belongs_to :spent_by_transaction, class_name: 'Transaction', optional: true

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :spent_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :spent_amount_within_amount
  validates :expense_id, uniqueness: { scope: :funding_event_id }

  private

  def spent_amount_within_amount
    return if spent_amount.blank? || amount.blank?
    return if spent_amount <= amount

    errors.add(:spent_amount, 'cannot exceed amount')
  end
end
