# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  subject { build(:user) }

  setup do
    subject.skip_confirmation_notification!
  end

  context 'validations' do
    should validate_presence_of(:name)
    should validate_presence_of(:email)

    should validate_uniqueness_of(:email).case_insensitive
  end

  context 'associations' do
    should have_many(:bank_accounts).dependent(:destroy)
  end
end
