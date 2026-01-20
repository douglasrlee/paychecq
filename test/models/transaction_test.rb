require 'test_helper'

class TransactionTest < ActiveSupport::TestCase
  test 'is valid with name and amount' do
    transaction = Transaction.new(name: 'Grocery Store', amount: 50.00)

    assert transaction.valid?
  end

  test 'is invalid without name' do
    transaction = Transaction.new(amount: 50.00)

    assert_not transaction.valid?
    assert_includes transaction.errors[:name], "can't be blank"
  end

  test 'is invalid without amount' do
    transaction = Transaction.new(name: 'Grocery Store')

    assert_not transaction.valid?
    assert_includes transaction.errors[:amount], "can't be blank"
  end

  test 'is invalid with non-numeric amount' do
    transaction = Transaction.new(name: 'Grocery Store', amount: 'not a number')

    assert_not transaction.valid?
    assert_includes transaction.errors[:amount], 'is not a number'
  end
end
