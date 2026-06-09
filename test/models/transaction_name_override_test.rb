require 'test_helper'

class TransactionNameOverrideTest < ActiveSupport::TestCase
  setup { @user = users(:johndoe) }

  test 'is valid with all required fields' do
    override = @user.transaction_name_overrides.new(match_type: 'exact', match_text: 'AMAZON', replacement_name: 'Amazon')

    assert override.valid?
  end

  test 'requires match_type to be exact or contains' do
    override = @user.transaction_name_overrides.new(match_type: 'regex', match_text: 'AMAZON', replacement_name: 'Amazon')

    assert_not override.valid?
    assert_includes override.errors[:match_type], 'must be exact or contains'
  end

  test 'requires match_text' do
    override = @user.transaction_name_overrides.new(match_type: 'exact', replacement_name: 'Amazon')

    assert_not override.valid?
    assert_includes override.errors[:match_text], "can't be blank"
  end

  test 'requires replacement_name' do
    override = @user.transaction_name_overrides.new(match_type: 'exact', match_text: 'AMAZON')

    assert_not override.valid?
    assert_includes override.errors[:replacement_name], "can't be blank"
  end

  test 'enforces case-insensitive uniqueness scoped to user and match_type' do
    duplicate = @user.transaction_name_overrides.new(match_type: 'exact', match_text: 'testexact', replacement_name: 'Other')

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:match_text], 'already has an override for this match type'
  end

  test 'allows same match_text for different match_type' do
    override = @user.transaction_name_overrides.new(match_type: 'contains', match_text: 'TESTEXACT', replacement_name: 'Other')

    assert override.valid?
  end

  test 'allows same match_text for different user' do
    other_user = users(:janedoe)
    override = other_user.transaction_name_overrides.new(match_type: 'exact', match_text: 'TESTEXACT', replacement_name: 'Other')

    assert override.valid?
  end
end
