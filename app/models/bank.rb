class Bank < ApplicationRecord
  has_paper_trail

  encrypts :plaid_access_token

  # Magic bytes for common image formats (binary encoded)
  IMAGE_SIGNATURES = {
    "\x89PNG\r\n\x1A\n".b => 'image/png',
    "\xFF\xD8\xFF".b => 'image/jpeg',
    'GIF8'.b => 'image/gif'
  }.freeze

  belongs_to :user

  has_many :bank_accounts, dependent: :destroy

  validates :name, :plaid_item_id, :plaid_access_token, :plaid_institution_id, :plaid_institution_name, presence: true
  validates :plaid_item_id, uniqueness: true
  validates :user_id, uniqueness: { message: 'already has a linked bank account' }
  validate :logo_is_valid_image, if: -> { logo.present? }

  before_destroy :unlink_from_plaid

  def logo_data_uri
    return nil if logo.blank?

    mime_type = detect_logo_mime_type
    return nil unless mime_type

    "data:#{mime_type};base64,#{logo}"
  rescue ArgumentError
    nil
  end

  private

  def detect_logo_mime_type
    decoded = Base64.strict_decode64(logo)
    IMAGE_SIGNATURES.each do |signature, mime_type|
      return mime_type if decoded.start_with?(signature)
    end
    nil
  end

  def logo_is_valid_image
    errors.add(:logo, 'must be a valid PNG, JPEG, or GIF image') if detect_logo_mime_type.nil?
  rescue ArgumentError
    errors.add(:logo, 'must be valid base64-encoded data')
  end

  def unlink_from_plaid
    return if PlaidService.remove_item(plaid_access_token)

    errors.add(:base, 'Failed to unlink from Plaid. Please try again.')
    throw :abort
  end
end
