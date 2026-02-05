class Bank < ApplicationRecord
  encrypts :plaid_access_token

  # Magic bytes for common image formats (binary encoded)
  IMAGE_SIGNATURES = [
    "\x89PNG\r\n\x1A\n".b,  # PNG
    "\xFF\xD8\xFF".b,       # JPEG
    'GIF8'.b                # GIF
  ].freeze

  belongs_to :user

  has_many :bank_accounts, dependent: :destroy

  validates :name, :plaid_item_id, :plaid_access_token, :plaid_institution_id, :plaid_institution_name, presence: true
  validates :plaid_item_id, uniqueness: true
  validates :user_id, uniqueness: { message: 'already has a linked bank account' }
  validate :logo_is_valid_image, if: -> { logo.present? }

  before_destroy :unlink_from_plaid

  private

  def logo_is_valid_image
    decoded = Base64.strict_decode64(logo)
    return if IMAGE_SIGNATURES.any? { |sig| decoded.start_with?(sig) }

    errors.add(:logo, 'must be a valid PNG, JPEG, or GIF image')
  rescue ArgumentError
    errors.add(:logo, 'must be valid base64-encoded data')
  end

  def unlink_from_plaid
    return if PlaidService.remove_item(plaid_access_token)

    errors.add(:base, 'Failed to unlink from Plaid. Please try again.')
    throw :abort
  end
end
