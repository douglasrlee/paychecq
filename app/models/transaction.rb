class Transaction < ApplicationRecord
  validates :name, :amount, presence: true
  validates :amount, numericality: true
end
