class Transaction < ApplicationRecord
  has_paper_trail

  belongs_to :bank_account, optional: true
  belongs_to :expense, optional: true

  validates :name, :amount, presence: true
  validates :amount, numericality: true
  validates :plaid_transaction_id, uniqueness: true, allow_nil: true

  def display_name(transaction_name_overrides = [])
    applied_override(transaction_name_overrides)&.replacement_name || name
  end

  def display_label(transaction_name_overrides = [])
    applied_override(transaction_name_overrides)&.replacement_name || merchant_name.presence || name
  end

  def applied_override(transaction_name_overrides)
    exact = transaction_name_overrides.find { |o| o.match_type == 'exact' && name.casecmp?(o.match_text) }
    return exact if exact

    downcased_name = name.downcase
    transaction_name_overrides.find { |o| o.match_type == 'contains' && downcased_name.include?(o.match_text.downcase) }
  end

  def safe_logo_url
    return nil if logo_url.blank?

    uri = URI.parse(logo_url)
    uri.scheme.in?(%w[http https]) ? logo_url : nil
  rescue URI::InvalidURIError
    nil
  end
end
