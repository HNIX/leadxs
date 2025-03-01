require "test_helper"

class VerticalFieldTest < ActiveSupport::TestCase
  test "should create a valid vertical field" do
    vertical_field = VerticalField.new(
      name: "test_field",
      data_type: "text",
      vertical: verticals(:insurance),
      account: accounts(:one)
    )
    assert vertical_field.valid?
  end

  test "should require a name" do
    vertical_field = VerticalField.new(
      data_type: "text",
      vertical: verticals(:insurance),
      account: accounts(:one)
    )
    assert_not vertical_field.valid?
    assert_includes vertical_field.errors[:name], "can't be blank"
  end

  test "should require a data type" do
    vertical_field = VerticalField.new(
      name: "test_field",
      vertical: verticals(:insurance),
      account: accounts(:one)
    )
    assert_not vertical_field.valid?
    assert_includes vertical_field.errors[:data_type], "can't be blank"
  end

  test "name should be unique within a vertical" do
    # Create a field first
    VerticalField.create!(
      name: "duplicate_field",
      data_type: "text",
      vertical: verticals(:insurance),
      account: accounts(:one)
    )

    # Try to create another with same name
    duplicate = VerticalField.new(
      name: "duplicate_field",
      data_type: "number",
      vertical: verticals(:insurance),
      account: accounts(:one)
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"

    # Should allow same name in different vertical
    different_vertical = VerticalField.new(
      name: "duplicate_field",
      data_type: "text",
      vertical: verticals(:home_services),
      account: accounts(:one)
    )
    assert different_vertical.valid?
  end

  test "should validate list values if value acceptance is list" do
    vertical_field = VerticalField.new(
      name: "list_field",
      data_type: "text",
      value_acceptance: "list",
      vertical: verticals(:insurance),
      account: accounts(:one)
    )
    assert_not vertical_field.valid?
    assert_includes vertical_field.errors[:list_values], "must be provided when value acceptance is set to list"

    # Add list values and try again
    vertical_field.list_values.build(list_value: "Option 1", account: accounts(:one))
    vertical_field.list_values.build(list_value: "Option 2", account: accounts(:one))
    assert vertical_field.valid?
  end

  test "should validate range values if value acceptance is range" do
    vertical_field = VerticalField.new(
      name: "range_field",
      data_type: "number",
      value_acceptance: "range",
      vertical: verticals(:insurance),
      account: accounts(:one)
    )
    assert_not vertical_field.valid?
    assert_includes vertical_field.errors[:min_value], "must be provided when value acceptance is set to range"
    assert_includes vertical_field.errors[:max_value], "must be provided when value acceptance is set to range"

    # Add range values and try again
    vertical_field.min_value = 1
    vertical_field.max_value = 100
    assert vertical_field.valid?
  end

  test "generate_example_value returns appropriate values based on data type" do
    text_field = VerticalField.new(data_type: "text")
    assert_equal "Sample Text", text_field.generate_example_value

    number_field = VerticalField.new(data_type: "number", min_value: 10, max_value: 20)
    assert_equal 15.0, number_field.generate_example_value

    boolean_field = VerticalField.new(data_type: "boolean")
    assert_equal true, boolean_field.generate_example_value

    date_field = VerticalField.new(data_type: "date")
    assert_equal Date.today.to_s, date_field.generate_example_value

    email_field = VerticalField.new(data_type: "email")
    assert_equal "example@email.com", email_field.generate_example_value

    phone_field = VerticalField.new(data_type: "phone")
    assert_equal "+1234567890", phone_field.generate_example_value
  end

  test "format_description returns appropriate descriptions based on data type and validation" do
    # Text field with any value
    text_field = VerticalField.new(data_type: "text", value_acceptance: "any")
    assert_equal "Any text", text_field.format_description

    # Number field with range
    number_field = VerticalField.new(data_type: "number", value_acceptance: "range", min_value: 5, max_value: 10)
    assert_equal "Number between 5 and 10", number_field.format_description

    # Boolean field
    boolean_field = VerticalField.new(data_type: "boolean")
    assert_equal "true or false", boolean_field.format_description

    # Email field
    email_field = VerticalField.new(data_type: "email")
    assert_equal "Valid email address", email_field.format_description

    # Text field with list values
    list_field = VerticalField.new(data_type: "text", value_acceptance: "list")
    list_field.list_values.build(list_value: "Option 1")
    list_field.list_values.build(list_value: "Option 2")
    assert_includes list_field.format_description, "One of:"
    assert_includes list_field.format_description, "Option 1, Option 2"
  end
end