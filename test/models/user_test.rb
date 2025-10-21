require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid factory from fixtures" do
    assert users(:john).valid?
    assert users(:jane).valid?
  end

  test "requires first_name, last_name, and email" do
    user = User.new

    assert_not user.valid?
    assert_includes user.errors.attribute_names, :first_name
    assert_includes user.errors.attribute_names, :last_name
    assert_includes user.errors.attribute_names, :email

    assert_includes user.errors[:first_name], "can't be blank"
    assert_includes user.errors[:last_name], "can't be blank"
    assert_includes user.errors[:email], "can't be blank"
  end

  test "email format validation" do
    user = User.new(first_name: "A", last_name: "B")

    invalid_emails = [
      "plainaddress",
      "@no-local-part.com",
      "username@",
      "username@.com",
      "username@site,com",
      "username@site..com",
      "username@site._com"
    ]

    invalid_emails.each do |email|
      user.email = email
      user.password = "password"
      assert_not user.valid?, "Expected '#{email}' to be invalid"
      assert_includes user.errors.attribute_names, :email
      assert_includes user.errors[:email], "is invalid"
    end

    valid_emails = [
      "u@example.com",
      "USER@EXAMPLE.COM",
      "first.last@sub.example.co.uk",
      "name+tag@domain.io"
    ]

    valid_emails.each do |email|
      user.email = email
      user.password = "password"
      assert user.valid?, "Expected '#{email}' to be valid: #{user.errors.full_messages.join(", ")}"
    end
  end

  test "email uniqueness is case-insensitive" do
    original = users(:john)
    dup = User.new(
      first_name: original.first_name,
      last_name: original.last_name,
      email: original.email.upcase,
      password: "password"
    )

    assert_not dup.valid?
    assert_includes dup.errors[:email], "has already been taken"
  end

  test "has_secure_password enforces password and authenticate works" do
    user = User.new(
      first_name: "New",
      last_name: "User",
      email: "newuser@example.com"
    )

    assert_not user.valid?, "User should be invalid without password"
    assert_includes user.errors.attribute_names, :password
    assert_includes user.errors[:password], "can't be blank"

    user.password = "secret123"
    user.password_confirmation = "secret123"

    assert user.valid?, user.errors.full_messages.to_s
    assert user.save!

    assert user.authenticate("secret123"), "Expected authenticate to succeed with correct password"
    assert_not user.authenticate("wrong"), "Expected authenticate to fail with wrong password"
  end

  test "destroying user cascades to sessions" do
    user = User.create!(
      first_name: "Sess",
      last_name: "Owner",
      email: "sess.owner@example.com",
      password: "password",
      password_confirmation: "password"
    )

    Session.create!(user: user, ip_address: "127.0.0.1", user_agent: "Test")
    Session.create!(user: user, ip_address: "127.0.0.2", user_agent: "Test2")

    assert_equal 2, user.sessions.count

    assert_difference -> { Session.count }, -2 do
      user.destroy!
    end
  end
end
