class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  validates_presence_of(:first_name, :last_name, :email_address)
  validates_uniqueness_of(:email_address, case_sensitive: false)

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
