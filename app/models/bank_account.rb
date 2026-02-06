class BankAccount < ApplicationRecord
  belongs_to :bank

  has_many :transactions, dependent: :destroy

  validates :name, :account_type, :plaid_account_id, :last_synced_at, presence: true
  validates :plaid_account_id, uniqueness: true

  delegate :user, to: :bank
end
