# Sets an expense/goal bucket's allocated balance to a target the user typed,
# adding from or returning to Free-to-Spend by the difference. The allocated
# balance is bucket_balance — the unspent remainder of every funded allocation,
# whether the paycheck engine proposed it or the user added it by hand.
#
# Increases go onto a single manual allocation row (no funding_event, funded_at
# set), which the engine subtracts from future paycheck proposals (see
# AllocationEngine.compute_proposed_amount). Decreases draw down funded money —
# the manual row first, then auto allocations newest-first — never below what a
# linked transaction already spent.
#
# Serialized with two nested row locks: the user row (matching
# AllocationEngine.fund_pending_for) so the Free-to-Spend baseline can't shift
# mid-calc, then the bucket row (matching ExpenseLinker/GoalLinker, which set
# spent_amount under that same lock) so a concurrent link can't slip in between
# our read and write and leave an allocation with amount < spent_amount.
# Per-row save!/update!/destroy! keeps callbacks + PaperTrail intact.
class ManualAllocator
  Result = Struct.new(:ok, :error) do
    def ok? = ok
  end

  def self.set_balance(item:, amount:)
    new(item).set_balance(amount)
  end

  def initialize(item)
    @item = item
    @user = item.user
  end

  # rubocop:disable Naming/AccessorMethodName -- a command (set the bucket to a
  # target), not an attribute writer.
  def set_balance(amount)
    target = round(amount)
    return failure('Enter an amount of zero or more.') if target.negative?

    # User-then-bucket order matches the other services (linkers lock the
    # transaction/bucket, never the user; fund_pending_for locks the user only),
    # so this can't deadlock against them.
    @user.with_lock do
      @item.with_lock do
        delta = target - @item.bucket_balance
        if delta.positive?
          return failure("That's more than your Free-to-Spend.") if delta > @user.free_to_spend

          add(delta)
        elsif delta.negative?
          remove(-delta)
        end
      end
    end

    success
  end
  # rubocop:enable Naming/AccessorMethodName

  private

  def add(amount)
    row = @item.allocations.manual.first_or_initialize
    row.funded_at ||= Time.current
    row.amount = (row.amount || 0) + amount
    row.save!
  end

  def remove(amount)
    remaining = amount
    drawable_allocations.each do |allocation|
      break if remaining <= 0

      available = allocation.amount - allocation.spent_amount
      take = [ available, remaining ].min
      new_amount = allocation.amount - take

      if new_amount <= allocation.spent_amount && allocation.spent_amount.zero?
        allocation.destroy!
      else
        allocation.update!(amount: [ new_amount, allocation.spent_amount ].max)
      end
      remaining -= take
    end
  end

  # Funded, unspent allocations to draw down, most-discretionary first: the
  # user's own manual row before any scheduled paycheck money, then auto
  # allocations newest-first (pull back the most recent funding first).
  def drawable_allocations
    # Manual row first (funding_event_id IS NULL sorts ahead of NOT NULL), then
    # auto allocations newest-first. Ordered in SQL, then materialized so we can
    # mutate rows while iterating.
    @item.allocations.where.not(funded_at: nil)
         .where('amount > spent_amount')
         .order(Arel.sql('funding_event_id IS NOT NULL, created_at DESC'))
         .to_a
  end

  def round(amount) = amount.to_d.round(2)

  def success = Result.new(true, nil)

  def failure(message) = Result.new(false, message)
end
