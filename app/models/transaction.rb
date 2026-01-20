class Transaction < ApplicationRecord
  has_paper_trail

  validates :name, :amount, presence: true
  validates :amount, numericality: true
end
