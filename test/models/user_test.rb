require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "is valid with all required attributes" do
    user = User.new(
      first_name: "Test",
      last_name: "User",
      email_address: "test@example.com",
      password: "password"
    )

    assert user.valid?
  end

  test "is invalid without first_name" do
    user = User.new(
      last_name: "User",
      email_address: "test@example.com",
      password: "password"
    )

    assert_not user.valid?
    assert_includes user.errors[:first_name], "can't be blank"
  end

  test "is invalid without last_name" do
    user = User.new(
      first_name: "Test",
      email_address: "test@example.com",
      password: "password"
    )

    assert_not user.valid?
    assert_includes user.errors[:last_name], "can't be blank"
  end

  test "is invalid without email_address" do
    user = User.new(
      first_name: "Test",
      last_name: "User",
      password: "password"
    )

    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "is invalid with duplicate email_address" do
    User.create!(
      first_name: "Existing",
      last_name: "User",
      email_address: "duplicate@example.com",
      password: "password"
    )

    user = User.new(
      first_name: "New",
      last_name: "User",
      email_address: "duplicate@example.com",
      password: "password"
    )

    assert_not user.valid?
    assert_includes user.errors[:email_address], "has already been taken"
  end

  test "is invalid with duplicate email_address regardless of case" do
    User.create!(
      first_name: "Existing",
      last_name: "User",
      email_address: "duplicate@example.com",
      password: "password"
    )

    user = User.new(
      first_name: "New",
      last_name: "User",
      email_address: "DUPLICATE@EXAMPLE.COM",
      password: "password"
    )

    assert_not user.valid?
    assert_includes user.errors[:email_address], "has already been taken"
  end

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")

    assert_equal("downcased@example.com", user.email_address)
  end
end
