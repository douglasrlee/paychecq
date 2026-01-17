class Transaction < ApplicationRecord
  validates :name, :amount, presence: true
end
