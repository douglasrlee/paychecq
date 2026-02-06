class Bank < ApplicationRecord
  has_paper_trail

  encrypts :plaid_access_token

  STATUSES = %w[healthy error pending_expiration disconnected].freeze

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
  validates :status, inclusion: { in: STATUSES }
  validate :logo_is_valid_image, if: -> { logo.present? }

  before_destroy :unlink_from_plaid

  def healthy?
    status == 'healthy'
  end

  def error?
    status == 'error'
  end

  def pending_expiration?
    status == 'pending_expiration'
  end

  def disconnected?
    status == 'disconnected'
  end

  def needs_attention?
    !healthy?
  end

  def mark_error!(error_code: nil)
    update!(status: 'error', plaid_error_code: error_code)
  end

  def mark_pending_expiration!
    update!(status: 'pending_expiration', plaid_error_code: nil)
  end

  def mark_disconnected!
    update!(status: 'disconnected', plaid_error_code: nil)
  end

  def mark_healthy!
    update!(status: 'healthy', plaid_error_code: nil)
  end

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
