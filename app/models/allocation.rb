class Allocation < ApplicationRecord
  has_paper_trail
  belongs_to :funding_event
  belongs_to :expense

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :expense_id, uniqueness: { scope: :funding_event_id }
end
