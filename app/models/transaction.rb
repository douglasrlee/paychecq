class Transaction < ApplicationRecord
  has_paper_trail

  belongs_to :bank_account, optional: true

  validates :name, :amount, presence: true
  validates :amount, numericality: true
  validates :plaid_transaction_id, uniqueness: true, allow_nil: true

  def safe_logo_url
    return nil if logo_url.blank?

    uri = URI.parse(logo_url)
    uri.scheme.in?(%w[http https]) ? logo_url : nil
  rescue URI::InvalidURIError
    nil
  end
end
