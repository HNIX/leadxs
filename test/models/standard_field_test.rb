require "test_helper"

class StandardFieldTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    ActsAsTenant.current_tenant = @account
    @standard_field = @account.standard_fields.new(
      name: "test_field",
      label: "Test Field",
      data_type: "text",
      required: true,
      description: "This is a test field"
    )
  end
  
  test "should be valid with valid attributes" do
    assert @standard_field.valid?
  end
  
  test "should not be valid without a name" do
    @standard_field.name = nil
    assert_not @standard_field.valid?
  end
  
  test "should not be valid without a data_type" do
    @standard_field.data_type = nil
    assert_not @standard_field.valid?
  end
  
  test "should not be valid with duplicate name in same account" do
    @standard_field.save!
    duplicate = @account.standard_fields.new(
      name: "test_field",
      label: "Duplicate Field",
      data_type: "text"
    )
    assert_not duplicate.valid?
  end
  
  test "should be valid with same name in different account" do
    @standard_field.save!
    
    other_account = accounts(:two)
    ActsAsTenant.with_tenant(other_account) do
      field = other_account.standard_fields.new(
        name: "test_field",
        label: "Same Field Name",
        data_type: "text"
      )
      assert field.valid?
    end
  end
  
  test "should require list values when value acceptance is list" do
    @standard_field.value_acceptance = "list"
    assert_not @standard_field.valid?
    assert_includes @standard_field.errors.full_messages, "List values must be provided when value acceptance is set to list"
  end
  
  test "should require min and max value when value acceptance is range" do
    @standard_field.value_acceptance = "range"
    assert_not @standard_field.valid?
    assert_includes @standard_field.errors.full_messages, "Min value must be provided when value acceptance is set to range"
    assert_includes @standard_field.errors.full_messages, "Max value must be provided when value acceptance is set to range"
  end
  
  test "should generate example value based on data type" do
    text_field = @account.standard_fields.new(name: "text_field", data_type: "text")
    assert_equal "Sample Text", text_field.generate_example_value
    
    number_field = @account.standard_fields.new(name: "number_field", data_type: "number")
    assert_equal 42, number_field.generate_example_value
    
    boolean_field = @account.standard_fields.new(name: "boolean_field", data_type: "boolean")
    assert_equal true, boolean_field.generate_example_value
    
    date_field = @account.standard_fields.new(name: "date_field", data_type: "date")
    assert_equal Date.today.to_s, date_field.generate_example_value
    
    email_field = @account.standard_fields.new(name: "email_field", data_type: "email")
    assert_equal "example@email.com", email_field.generate_example_value
    
    phone_field = @account.standard_fields.new(name: "phone_field", data_type: "phone")
    assert_equal "+1234567890", phone_field.generate_example_value
  end
  
  test "should apply standard fields to vertical" do
    @standard_field.save!
    
    vertical = @account.verticals.create!(
      name: "Test Vertical",
      primary_category: "Test"
    )
    
    # Remove auto-created fields
    vertical.vertical_fields.delete_all
    assert_equal 0, vertical.vertical_fields.count
    
    # Apply standard fields
    StandardField.apply_to_vertical(vertical)
    
    # Verify field was created
    assert_equal 1, vertical.vertical_fields.count
    field = vertical.vertical_fields.first
    assert_equal @standard_field.name, field.name
    assert_equal @standard_field.label, field.label
    assert_equal @standard_field.data_type, field.data_type
    assert_equal @standard_field.required, field.required
    assert_equal @standard_field.description, field.description
  end
end
