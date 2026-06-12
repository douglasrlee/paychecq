class PushSubscription < ApplicationRecord
  has_paper_trail
  belongs_to :user

  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh_key, :auth_key, presence: true
end
