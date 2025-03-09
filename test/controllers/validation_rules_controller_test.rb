require "test_helper"

class ValidationRulesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @account = accounts(:one)
    @user = users(:one)
    @campaign = campaigns(:one)
    @vertical = verticals(:insurance)
    
    # Create validation rules directly for testing since fixtures might have issues
    # with polymorphic associations
    ActsAsTenant.with_tenant(@account) do
      @validation_rule = ValidationRule.create!(
        validatable: @campaign,
        name: "Test Email Validation",
        rule_type: "pattern",
        condition: "true",
        error_message: "Please enter a valid email address",
        severity: "error",
        active: true,
        parameters: { field_name: "email", pattern: '\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z' }.to_json
      )
      
      @vertical_validation_rule = ValidationRule.create!(
        validatable: @vertical,
        name: "Test Name Validation",
        rule_type: "condition",
        condition: "!String.empty?(field('first_name'))",
        error_message: "First name is required",
        severity: "error",
        active: true,
        parameters: {}.to_json
      )
    end
    
    sign_in @user
    ActsAsTenant.current_tenant = @account
  end
  
  teardown do
    # Clean up test records
    ActsAsTenant.with_tenant(@account) do
      ValidationRule.where(id: [@validation_rule.id, @vertical_validation_rule.id]).destroy_all
    end
    
    ActsAsTenant.current_tenant = nil
  end
  
  test "should get index for campaign" do
    get campaign_validation_rules_url(@campaign)
    assert_response :success
  end
  
  test "should get index for vertical" do
    get vertical_validation_rules_url(@vertical)
    assert_response :success
  end
  
  test "should get new for campaign" do
    get new_campaign_validation_rule_url(@campaign)
    assert_response :success
  end
  
  test "should get new for vertical" do
    get new_vertical_validation_rule_url(@vertical)
    assert_response :success
  end
  
  test "should create validation rule for campaign" do
    assert_difference("ValidationRule.count") do
      post campaign_validation_rules_url(@campaign), params: {
        validation_rule: {
          name: "New Test Rule",
          rule_type: "condition",
          condition: "!String.empty?(field('test_field'))",
          error_message: "Test field cannot be empty",
          severity: "error"
        }
      }
    end
    
    new_rule = ValidationRule.find_by(name: "New Test Rule")
    assert_not_nil new_rule
    assert_equal @campaign.id, new_rule.validatable_id
    assert_equal "Campaign", new_rule.validatable_type
    assert_redirected_to campaign_validation_rule_url(@campaign, new_rule)
  end
  
  test "should show validation rule for campaign" do
    get campaign_validation_rule_url(@campaign, @validation_rule)
    assert_response :success
  end
  
  test "should get edit for campaign validation rule" do
    get edit_campaign_validation_rule_url(@campaign, @validation_rule)
    assert_response :success
  end
  
  test "should update validation rule for campaign" do
    patch campaign_validation_rule_url(@campaign, @validation_rule), params: {
      validation_rule: {
        name: "Updated Rule Name",
        error_message: "Updated error message"
      }
    }
    
    @validation_rule.reload
    assert_equal "Updated Rule Name", @validation_rule.name
    assert_equal "Updated error message", @validation_rule.error_message
    assert_redirected_to campaign_validation_rule_url(@campaign, @validation_rule)
  end
  
  test "should destroy validation rule" do
    assert_difference("ValidationRule.count", -1) do
      delete campaign_validation_rule_url(@campaign, @validation_rule)
    end
    
    assert_redirected_to campaign_validation_rules_url(@campaign)
  end
  
  test "should toggle validation rule active state" do
    # Start with an active rule
    assert @validation_rule.active?
    
    # Toggle to inactive
    patch toggle_active_campaign_validation_rule_url(@campaign, @validation_rule)
    @validation_rule.reload
    assert_not @validation_rule.active?
    
    # Toggle back to active
    patch toggle_active_campaign_validation_rule_url(@campaign, @validation_rule)
    @validation_rule.reload
    assert @validation_rule.active?
  end
  
  test "should test validation rule" do
    test_data = { email: "test@example.com" }
    
    post test_campaign_validation_rules_url(@campaign), params: {
      test_data: test_data,
      validation_rule: {
        rule_type: "pattern",
        name: "Test Rule",
        condition: "true",
        error_message: "Invalid email",
        parameters: { field_name: "email", pattern: '\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z' }.to_json
      }
    }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["valid"]
  end
end
