class User < ApplicationRecord
  has_paper_trail
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :banks, dependent: :destroy
  has_many :bank_accounts, through: :banks
  has_many :transactions, through: :bank_accounts
  has_many :push_subscriptions, dependent: :destroy
  has_many :transaction_name_overrides, dependent: :destroy
  has_many :funding_schedules, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :goals, dependent: :destroy

  validates :first_name, :last_name, :email_address, presence: true
  validates :email_address, uniqueness: { case_sensitive: false }
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :email_on_allowlist, on: :create

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Money the bank says is spendable right now.
  def available_balance
    bank_accounts.sum(:available_balance)
  end

  # Money sitting in expense + goal buckets: the unspent remainder of every
  # funded allocation across both. Single aggregate query per type (mirrors the
  # expenses/goals list headers) so it stays cheap on the index pages.
  def allocated_in_buckets
    expense_allocated = expenses.joins(:allocations)
                                .where.not(allocations: { funded_at: nil })
                                .where('allocations.amount > allocations.spent_amount')
                                .sum(Arel.sql('allocations.amount - allocations.spent_amount'))
    goal_allocated = goals.joins(:allocations)
                          .where.not(allocations: { funded_at: nil })
                          .where('allocations.amount > allocations.spent_amount')
                          .sum(Arel.sql('allocations.amount - allocations.spent_amount'))
    expense_allocated + goal_allocated
  end

  # What's left to spend freely after buckets are funded. Manual allocations
  # draw against this; ManualAllocator won't let an add push it negative.
  def free_to_spend
    available_balance - allocated_in_buckets
  end

  private

  def email_on_allowlist
    allowed = ENV.fetch('ALLOWED_EMAILS', nil)

    return if allowed.blank? || email_address.blank?

    emails = allowed.split(',').map { |e| e.strip.downcase }

    errors.add(:email_address, 'is not authorized to sign up') unless emails.include?(email_address)
  end
end
