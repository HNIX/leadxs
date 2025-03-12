require "test_helper"

class StandardFieldsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @standard_field = standard_fields(:first_name)
    
    ActsAsTenant.current_tenant = @account
    sign_in @user
  end
  
  test "should get index" do
    get standard_fields_url
    assert_response :success
  end

  test "should get new" do
    get new_standard_field_url
    assert_response :success
  end

  test "should create standard field" do
    assert_difference("StandardField.count") do
      post standard_fields_url, params: {
        standard_field: {
          name: "new_field",
          label: "New Field",
          data_type: "text",
          value_acceptance: "any",
          required: true,
          description: "A new standard field"
        }
      }
    end

    assert_redirected_to standard_fields_url
    assert_equal "Standard field was successfully created.", flash[:notice]
  end

  test "should get edit" do
    get edit_standard_field_url(@standard_field)
    assert_response :success
  end

  test "should update standard field" do
    patch standard_field_url(@standard_field), params: {
      standard_field: {
        label: "Updated Label",
        description: "Updated description"
      }
    }
    
    assert_redirected_to standard_fields_url
    assert_equal "Standard field was successfully updated.", flash[:notice]
    @standard_field.reload
    assert_equal "Updated Label", @standard_field.label
    assert_equal "Updated description", @standard_field.description
  end

  test "should destroy standard field" do
    assert_difference("StandardField.count", -1) do
      delete standard_field_url(@standard_field)
    end

    assert_redirected_to standard_fields_url
    assert_equal "Standard field was successfully deleted.", flash[:notice]
  end
  
  test "should update positions" do
    standard_field2 = standard_fields(:last_name)
    standard_field3 = standard_fields(:email)
    
    # Update positions
    patch standard_field_positions_url(@standard_field), params: {
      position: [standard_field3.id.to_s, standard_field2.id.to_s, @standard_field.id.to_s]
    }
    
    assert_response :success
    
    # Verify positions were updated
    standard_field3.reload
    standard_field2.reload
    @standard_field.reload
    
    assert_equal 1, standard_field3.position
    assert_equal 2, standard_field2.position
    assert_equal 3, @standard_field.position
  end
end
