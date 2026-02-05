class BankAccount < ApplicationRecord
  belongs_to :bank

  validates :name, :masked_account_number, :account_type, :plaid_account_id, :last_synced_at, presence: true
  validates :plaid_account_id, uniqueness: true

  delegate :user, to: :bank
end
