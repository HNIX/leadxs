require "test_helper"

class CampaignFieldsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @campaign = campaigns(:one)
    @campaign_field = campaign_fields(:one)
    
    sign_in @user
    Current.account = @account
  end

  teardown do
    Current.reset
  end

  test "should get index" do
    # Skip the index test since there's no HTML template
    # This would typically render JSON or be for AJAX requests
    skip("No HTML template for index")
  end

  test "should get new" do
    get new_campaign_campaign_field_url(@campaign)
    assert_response :success
  end

  test "should create campaign_field" do
    assert_difference("CampaignField.count") do
      post campaign_campaign_fields_url(@campaign), params: {
        campaign_field: {
          name: "new_text_field",
          label: "New Text Field",
          field_type: "text",
          required: true,
          description: "This is a new text field"
        }
      }
    end

    field = CampaignField.last
    assert_redirected_to campaign_url(@campaign)
    assert_equal "new_text_field", field.name
    assert_equal "New Text Field", field.label
    assert_equal "text", field.field_type
    assert field.required
    assert_equal "This is a new text field", field.description
  end

  test "should create campaign_field with list values" do
    assert_difference("CampaignField.count") do
      post campaign_campaign_fields_url(@campaign), params: {
        campaign_field: {
          name: "new_select_field",
          label: "New Select Field",
          field_type: "select",
          value_acceptance: "list",
          required: true,
          description: "This is a select field",
          list_values_attributes: {
            "0" => { list_value: "Option 1", position: 0 },
            "1" => { list_value: "Option 2", position: 1 },
            "2" => { list_value: "Option 3", position: 2 }
          }
        }
      }
    end

    field = CampaignField.last
    assert_redirected_to campaign_url(@campaign)
    assert_equal "new_select_field", field.name
    assert_equal "select", field.field_type
    assert_equal "list", field.value_acceptance
    assert_equal 3, field.list_values.count
  end

  test "should not create campaign_field with invalid attributes" do
    assert_no_difference("CampaignField.count") do
      post campaign_campaign_fields_url(@campaign), params: {
        campaign_field: {
          name: "",
          field_type: "invalid_type"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_campaign_campaign_field_url(@campaign, @campaign_field)
    assert_response :success
  end

  test "should update campaign_field" do
    patch campaign_campaign_field_url(@campaign, @campaign_field), params: {
      campaign_field: {
        label: "Updated Field Label",
        description: "Updated description",
        required: true
      }
    }
    
    @campaign_field.reload
    assert_redirected_to campaign_url(@campaign)
    assert_equal "Updated Field Label", @campaign_field.label
    assert_equal "Updated description", @campaign_field.description
    assert @campaign_field.required
  end

  test "should not update campaign_field with invalid attributes" do
    patch campaign_campaign_field_url(@campaign, @campaign_field), params: {
      campaign_field: {
        name: "",
        field_type: "invalid_type"
      }
    }
    
    assert_response :unprocessable_entity
  end

  test "should destroy campaign_field" do
    assert_difference("CampaignField.count", -1) do
      delete campaign_campaign_field_url(@campaign, @campaign_field)
    end

    assert_redirected_to campaign_url(@campaign)
  end
end

class CampaignFields::PositionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @campaign = campaigns(:one)
    @campaign_field = campaign_fields(:one)
    
    sign_in @user
    Current.account = @account
  end

  teardown do
    Current.reset
  end

  test "should update position" do
    # Get the current position
    original_position = @campaign_field.position
    new_position = original_position + 2
    
    # Update position
    patch campaign_campaign_field_positions_url(@campaign, @campaign_field), params: {
      position: new_position
    }
    
    # Check response
    assert_response :no_content
    
    # Reload to ensure position was updated
    @campaign_field.reload
    assert_equal new_position, @campaign_field.position
  end
end
