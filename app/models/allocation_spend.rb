class AllocationSpend < ApplicationRecord
  # One transaction's draw against one funded allocation. Several spends can
  # point at the same allocation (a bucket paid by multiple transactions) and
  # several can point at the same transaction (one payment spread across
  # allocations). allocations.spent_amount is the maintained sum per allocation.
  belongs_to :allocation
  belongs_to :spent_by_transaction, class_name: 'Transaction'

  validates :amount, numericality: { greater_than: 0 }
end
