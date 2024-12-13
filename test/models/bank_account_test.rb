# frozen_string_literal: true

require 'test_helper'

class BankAccountTest < ActiveSupport::TestCase
  context 'validations' do
    should validate_presence_of(:name)
  end

  context 'associations' do
    should belong_to(:user)
  end
end
