class Transaction < ApplicationRecord
  has_paper_trail
  belongs_to :bank_account, optional: true

  validates :name, :amount, presence: true
  validates :amount, numericality: true
  validates :plaid_transaction_id, uniqueness: true, allow_nil: true
end
