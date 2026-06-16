class FundingEvent < ApplicationRecord
  has_paper_trail
  belongs_to :funding_schedule
  has_many :allocations, dependent: :destroy

  validates :occurs_on, presence: true
  validates :occurs_on, uniqueness: { scope: :funding_schedule_id }
end
