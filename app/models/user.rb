class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  validates :first_name, :last_name, :email_address, presence: true
  validates :email_address, uniqueness: { case_sensitive: false }

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
