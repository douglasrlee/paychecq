class PushSubscription < ApplicationRecord
  # Exclude the encryption keys from versioning — they're sensitive and
  # we only want lifecycle (create/update/destroy) tracked, not key values.
  has_paper_trail ignore: [ :p256dh_key, :auth_key ]
  belongs_to :user

  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh_key, :auth_key, presence: true
end
