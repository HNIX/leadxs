require "test_helper"

class VerticalFieldsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @account = accounts(:one)
    @vertical = verticals(:insurance)
    @field = vertical_fields(:text_field)
    
    sign_in @user
    ActsAsTenant.current_tenant = @account
  end

  test "should get index" do
    get vertical_vertical_fields_url(@vertical)
    assert_response :success
  end

  test "should get new" do
    get new_vertical_vertical_field_url(@vertical)
    assert_response :success
  end

  test "should create vertical field" do
    assert_difference("VerticalField.count") do
      post vertical_vertical_fields_url(@vertical), params: {
        vertical_field: {
          name: "test_field",
          label: "Test Field",
          data_type: "text",
          required: true,
          is_pii: false,
          value_acceptance: "any"
        }
      }
    end

    assert_redirected_to vertical_path(@vertical)
  end

  test "should create vertical field with list values" do
    assert_difference("VerticalField.count") do
      post vertical_vertical_fields_url(@vertical), params: {
        vertical_field: {
          name: "list_field_test",
          label: "List Field Test",
          data_type: "text",
          required: true,
          value_acceptance: "list",
          list_values_attributes: {
            "0" => { list_value: "Option A", value_type: "string" },
            "1" => { list_value: "Option B", value_type: "string" }
          }
        }
      }
    end

    assert_redirected_to vertical_path(@vertical)
    field = VerticalField.find_by(name: "list_field_test")
    assert_equal 2, field.list_values.count
  end

  test "should create vertical field with range" do
    assert_difference("VerticalField.count") do
      post vertical_vertical_fields_url(@vertical), params: {
        vertical_field: {
          name: "range_field_test",
          label: "Range Field Test",
          data_type: "number",
          required: true,
          value_acceptance: "range",
          min_value: "10",
          max_value: "100"
        }
      }
    end

    assert_redirected_to vertical_path(@vertical)
    field = VerticalField.find_by(name: "range_field_test")
    assert_equal 10.0, field.min_value.to_f
    assert_equal 100.0, field.max_value.to_f
  end

  test "should get edit" do
    get edit_vertical_vertical_field_url(@vertical, @field)
    assert_response :success
  end

  test "should update vertical field" do
    patch vertical_vertical_field_url(@vertical, @field), params: {
      vertical_field: {
        label: "Updated Label",
        required: false,
      }
    }

    assert_redirected_to vertical_path(@vertical)
    @field.reload
    assert_equal "Updated Label", @field.label
    assert_equal false, @field.required
  end

  test "should destroy vertical field" do
    assert_difference("VerticalField.count", -1) do
      delete vertical_vertical_field_url(@vertical, @field)
    end

    assert_redirected_to vertical_path(@vertical)
  end

  test "should move vertical field" do
    original_position = @field.position
    new_position = original_position + 2
    
    patch vertical_vertical_field_positions_path(@vertical, @field), params: { position: new_position }
    
    assert_response :success
    @field.reload
    assert_equal new_position, @field.position
  end
end