class Bank < ApplicationRecord
  encrypts :plaid_access_token

  belongs_to :user

  has_many :bank_accounts, dependent: :destroy

  validates :name, :plaid_item_id, :plaid_access_token, :plaid_institution_id, :plaid_institution_name, presence: true
  validates :plaid_item_id, uniqueness: true
  validates :user_id, uniqueness: { message: 'already has a linked bank account' }

  before_destroy :unlink_from_plaid

  private

  def unlink_from_plaid
    return if PlaidService.remove_item(plaid_access_token)

    errors.add(:base, 'Failed to unlink from Plaid. Please try again.')
    throw :abort
  end
end
