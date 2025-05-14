# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'valid user' do
    user = User.new(name: 'John Doe', email: 'johndoe@example.com', password: 'P@ssw0rd!')

    assert(user.valid?)
  end

  test 'invalid user without name' do
    user = User.new(name: nil, email: 'johndoe@example.com', password: 'P@ssw0rd!')

    assert(user.invalid?)
    assert_equal(user.errors[:name], [ 'can\'t be blank' ])
  end
end
