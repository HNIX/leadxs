require "test_helper"

class ListValueTest < ActiveSupport::TestCase
  setup do
    @vertical_field = VerticalField.create!(
      name: "test_field_with_list",
      data_type: "text",
      value_acceptance: "list",
      vertical: verticals(:insurance),
      account: accounts(:one)
    )
  end

  test "should create a valid list value" do
    list_value = ListValue.new(
      list_value: "Option 1",
      value_type: "string",
      list_owner: @vertical_field,
      account: accounts(:one)
    )
    assert list_value.valid?
  end

  test "should require a list value" do
    list_value = ListValue.new(
      value_type: "string",
      list_owner: @vertical_field,
      account: accounts(:one)
    )
    assert_not list_value.valid?
    assert_includes list_value.errors[:list_value], "can't be blank"
  end

  test "should validate number format when value type is number" do
    # Valid number
    list_value = ListValue.new(
      list_value: "42.5",
      value_type: "number",
      list_owner: @vertical_field,
      account: accounts(:one)
    )
    assert list_value.valid?

    # Invalid number
    list_value = ListValue.new(
      list_value: "not-a-number",
      value_type: "number",
      list_owner: @vertical_field,
      account: accounts(:one)
    )
    assert_not list_value.valid?
    assert_includes list_value.errors[:list_value], "must be a valid number"
  end

  test "should allow any string when value type is string" do
    list_value = ListValue.new(
      list_value: "Any text is fine",
      value_type: "string",
      list_owner: @vertical_field,
      account: accounts(:one)
    )
    assert list_value.valid?
  end

  test "should belong to a list owner" do
    list_value = ListValue.new(
      list_value: "Option",
      value_type: "string",
      account: accounts(:one)
    )
    assert_not list_value.valid?
    assert_includes list_value.errors[:list_owner], "must exist"
  end
end