class User < ApplicationRecord
  has_secure_password
  has_paper_trail

  has_many :sessions, dependent: :destroy

  validates :first_name, :last_name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
end
