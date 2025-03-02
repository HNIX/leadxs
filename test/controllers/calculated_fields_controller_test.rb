require "test_helper"

class CalculatedFieldsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @campaign = Campaign.create!(
      name: "Test Campaign", 
      status: "active", 
      campaign_type: "ping_post", 
      distribution_method: "highest_bid",
      vertical: verticals(:insurance),
      account: @account
    )
    
    @calculated_field = CalculatedField.create!(
      name: "Age", 
      formula: "YEAR(NOW()) - YEAR(date_of_birth)",
      status: "active",
      campaign: @campaign,
      account: @account
    )
    
    sign_in @user
    Current.account = @account
  end
  
  test "should get index" do
    get campaign_calculated_fields_url(@campaign)
    assert_response :success
  end
  
  test "should get new" do
    get new_campaign_calculated_field_url(@campaign)
    assert_response :success
  end
  
  test "should create calculated field" do
    assert_difference("CalculatedField.count") do
      post campaign_calculated_fields_url(@campaign), params: { 
        calculated_field: { 
          name: "Income Score", 
          formula: "income * 0.01", 
          status: "active" 
        } 
      }
    end
    
    assert_redirected_to campaign_calculated_field_url(@campaign, CalculatedField.last)
    assert_equal "Income Score", CalculatedField.last.name
    assert_equal "income * 0.01", CalculatedField.last.formula
    assert_equal @account.id, CalculatedField.last.account_id
  end
  
  test "should show calculated field" do
    get campaign_calculated_field_url(@campaign, @calculated_field)
    assert_response :success
  end
  
  test "should get edit" do
    get edit_campaign_calculated_field_url(@campaign, @calculated_field)
    assert_response :success
  end
  
  test "should update calculated field" do
    patch campaign_calculated_field_url(@campaign, @calculated_field), params: { 
      calculated_field: { 
        formula: "YEAR(CURRENT_DATE) - YEAR(dob)"
      } 
    }
    
    assert_redirected_to campaign_calculated_field_url(@campaign, @calculated_field)
    @calculated_field.reload
    assert_equal "YEAR(CURRENT_DATE) - YEAR(dob)", @calculated_field.formula
  end
  
  test "should destroy calculated field" do
    assert_difference("CalculatedField.count", -1) do
      delete campaign_calculated_field_url(@campaign, @calculated_field)
    end
    
    assert_redirected_to campaign_calculated_fields_url(@campaign)
  end
  
  test "should not create calculated field with duplicate name" do
    assert_no_difference("CalculatedField.count") do
      post campaign_calculated_fields_url(@campaign), params: { 
        calculated_field: { 
          name: "Age", 
          formula: "Something different", 
          status: "active" 
        } 
      }
    end
    
    assert_response :unprocessable_entity
  end
  
  test "should not create calculated field without formula" do
    assert_no_difference("CalculatedField.count") do
      post campaign_calculated_fields_url(@campaign), params: { 
        calculated_field: { 
          name: "New Field", 
          status: "active" 
        } 
      }
    end
    
    assert_response :unprocessable_entity
  end
end
