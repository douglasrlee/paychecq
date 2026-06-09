class TransactionNameOverride < ApplicationRecord
  belongs_to :user

  MATCH_TYPES = %w[exact contains].freeze

  validates :match_type, inclusion: { in: MATCH_TYPES, message: 'must be exact or contains' }
  validates :match_text, :replacement_name, presence: true
  validates :match_text, uniqueness: {
    scope: [ :user_id, :match_type ],
    case_sensitive: false,
    message: 'already has an override for this match type'
  }
end
