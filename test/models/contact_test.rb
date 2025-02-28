require "test_helper"

class ContactTest < ActiveSupport::TestCase
  test "should create a valid contact" do
    contact = Contact.new(
      first_name: "John",
      last_name: "Doe",
      email: "john@example.com",
      phone: "123-456-7890",
      company: companies(:one),
      account: accounts(:one)
    )
    assert contact.valid?
  end

  test "should require first_name" do
    contact = Contact.new(
      last_name: "Doe",
      email: "john@example.com",
      company: companies(:one),
      account: accounts(:one)
    )
    assert_not contact.valid?
    assert_includes contact.errors[:first_name], "can't be blank"
  end

  test "should require last_name" do
    contact = Contact.new(
      first_name: "John",
      email: "john@example.com",
      company: companies(:one),
      account: accounts(:one)
    )
    assert_not contact.valid?
    assert_includes contact.errors[:last_name], "can't be blank"
  end

  test "should require email" do
    contact = Contact.new(
      first_name: "John",
      last_name: "Doe",
      company: companies(:one),
      account: accounts(:one)
    )
    assert_not contact.valid?
    assert_includes contact.errors[:email], "can't be blank"
  end

  test "should validate email format" do
    contact = Contact.new(
      first_name: "John",
      last_name: "Doe",
      email: "invalid-email",
      company: companies(:one),
      account: accounts(:one)
    )
    assert_not contact.valid?
    assert_includes contact.errors[:email], "is invalid"
  end

  test "should enforce email uniqueness within an account" do
    # Create a contact first
    Contact.create!(
      first_name: "John",
      last_name: "Doe",
      email: "duplicate@example.com",
      company: companies(:one),
      account: accounts(:one)
    )

    # Try to create another contact with the same email in the same account
    duplicate = Contact.new(
      first_name: "Jane",
      last_name: "Doe",
      email: "duplicate@example.com",
      company: companies(:one),
      account: accounts(:one)
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"

    # But it should allow the same email in a different account
    different_account = Contact.new(
      first_name: "Jane",
      last_name: "Doe",
      email: "duplicate@example.com",
      company: companies(:two),
      account: accounts(:two)
    )
    assert different_account.valid?
  end

  test "full_name method returns correct value" do
    contact = Contact.new(first_name: "John", last_name: "Doe")
    assert_equal "John Doe", contact.full_name
  end
end