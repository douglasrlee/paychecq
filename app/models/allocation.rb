class Allocation < ApplicationRecord
  has_paper_trail
  belongs_to :funding_event
  belongs_to :expense
  belongs_to :spent_by_transaction, class_name: 'Transaction', optional: true

  scope :unspent, -> { where(spent_at: nil) }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :expense_id, uniqueness: { scope: :funding_event_id }
end
