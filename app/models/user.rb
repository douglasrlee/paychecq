class User < ApplicationRecord
  has_paper_trail
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :banks, dependent: :destroy
  has_many :bank_accounts, through: :banks
  has_many :push_subscriptions, dependent: :destroy

  validates :first_name, :last_name, :email_address, presence: true
  validates :email_address, uniqueness: { case_sensitive: false }
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
