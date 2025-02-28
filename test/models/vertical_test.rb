require "test_helper"

class VerticalTest < ActiveSupport::TestCase
  test "should create a valid vertical" do
    vertical = Vertical.new(
      name: "Test Vertical",
      primary_category: "Insurance",
      secondary_category: "Auto",
      description: "A test vertical",
      archived: false,
      base: false,
      account: accounts(:one)
    )
    assert vertical.valid?
  end

  test "should require name" do
    vertical = Vertical.new(
      primary_category: "Insurance", 
      account: accounts(:one)
    )
    assert_not vertical.valid?
    assert_includes vertical.errors[:name], "can't be blank"
  end

  test "should require primary_category" do
    vertical = Vertical.new(
      name: "Test Vertical", 
      account: accounts(:one)
    )
    assert_not vertical.valid?
    assert_includes vertical.errors[:primary_category], "can't be blank"
  end

  test "name should be unique within an account" do
    # Try to create a vertical with the same name in the same account
    vertical = Vertical.new(
      name: verticals(:insurance).name,
      primary_category: "Finance",
      account: accounts(:one)
    )
    assert_not vertical.valid?
    assert_includes vertical.errors[:name], "has already been taken"

    # But should allow the same name in a different account
    vertical.account = accounts(:two)
    assert vertical.valid?
  end

  test "active scope returns only active verticals" do
    active_verticals = Vertical.active
    assert_includes active_verticals, verticals(:insurance)
    assert_not_includes active_verticals, verticals(:archived)
  end

  test "archived scope returns only archived verticals" do
    archived_verticals = Vertical.archived
    assert_includes archived_verticals, verticals(:archived)
    assert_not_includes archived_verticals, verticals(:insurance)
  end

  test "base scope returns only base verticals" do
    base_verticals = Vertical.base
    assert_includes base_verticals, verticals(:insurance)
    assert_not_includes base_verticals, verticals(:custom)
  end

  test "custom scope returns only custom verticals" do
    custom_verticals = Vertical.custom
    assert_includes custom_verticals, verticals(:custom)
    assert_not_includes custom_verticals, verticals(:insurance)
  end

  test "active? returns correct value" do
    assert verticals(:insurance).active?
    assert_not verticals(:archived).active?
  end

  test "archived? returns correct value" do
    assert verticals(:archived).archived?
    assert_not verticals(:insurance).archived?
  end

  test "base? returns correct value" do
    assert verticals(:insurance).base?
    assert_not verticals(:custom).base?
  end

  test "custom? returns correct value" do
    assert verticals(:custom).custom?
    assert_not verticals(:insurance).custom?
  end

  test "full_category returns primary and secondary when both exist" do
    assert_equal "Insurance - Auto", verticals(:insurance).full_category
  end

  test "full_category returns only primary when secondary missing" do
    vertical = Vertical.new(primary_category: "Finance")
    assert_equal "Finance", vertical.full_category
  end
end
