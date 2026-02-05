class Bank < ApplicationRecord
  encrypts :plaid_access_token

  belongs_to :user

  has_many :bank_accounts, dependent: :destroy

  validates :name, :plaid_item_id, :plaid_access_token, :plaid_institution_id, :plaid_institution_name, presence: true
  validates :plaid_item_id, uniqueness: true

  before_destroy :unlink_from_plaid

  private

  def unlink_from_plaid
    PlaidService.remove_item(plaid_access_token)
  end
end
