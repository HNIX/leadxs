require "test_helper"

class CalculatedFieldTest < ActiveSupport::TestCase
  test "valid calculated field" do
    account = accounts(:one)
    campaign = Campaign.create!(
      name: "Test Campaign",
      status: "active", 
      campaign_type: "ping_post",
      distribution_method: "highest_bid",
      vertical: verticals(:insurance),
      account: account
    )
    
    calculated_field = CalculatedField.new(
      name: "Age",
      formula: "YEAR(NOW()) - YEAR(date_of_birth)",
      status: "active",
      campaign: campaign,
      account: account
    )
    
    assert calculated_field.valid?
    
    # Call clean_formula_content method before assertion
    calculated_field.send(:clean_formula_content)
    assert_equal "YEAR(NOW()) - YEAR(date_of_birth)", calculated_field.clean_formula
  end
  
  test "requires name" do
    account = accounts(:one)
    campaign = Campaign.create!(
      name: "Test Campaign",
      status: "active", 
      campaign_type: "ping_post",
      distribution_method: "highest_bid",
      vertical: verticals(:insurance),
      account: account
    )
    
    calculated_field = CalculatedField.new(
      formula: "YEAR(NOW()) - YEAR(date_of_birth)",
      status: "active",
      campaign: campaign,
      account: account
    )
    
    assert_not calculated_field.valid?
    assert_includes calculated_field.errors[:name], "can't be blank"
  end
  
  test "requires formula" do
    account = accounts(:one)
    campaign = Campaign.create!(
      name: "Test Campaign",
      status: "active", 
      campaign_type: "ping_post",
      distribution_method: "highest_bid",
      vertical: verticals(:insurance),
      account: account
    )
    
    calculated_field = CalculatedField.new(
      name: "Age",
      status: "active",
      campaign: campaign,
      account: account
    )
    
    assert_not calculated_field.valid?
    assert_includes calculated_field.errors[:formula], "can't be blank"
  end
  
  test "handles error in formula" do
    account = accounts(:one)
    campaign = Campaign.create!(
      name: "Test Campaign",
      status: "active", 
      campaign_type: "ping_post",
      distribution_method: "highest_bid",
      vertical: verticals(:insurance),
      account: account
    )
    
    # Use mock to simulate an error
    calculated_field = CalculatedField.new(
      name: "Error Test",
      formula: "1/0", # This won't actually cause an error in the clean method, we'll mock it
      status: "active",
      campaign: campaign,
      account: account
    )
    
    # Mock the clean_formula_content method to simulate an error
    calculated_field.define_singleton_method(:clean_formula_content) do
      self.status = CalculatedField::STATUSES[:error]
      self.error_log = { error: "Test error", timestamp: Time.current }
    end
    
    # Save should work and error_log should be populated
    assert calculated_field.save
    assert_equal "error", calculated_field.status
    assert calculated_field.error_log.present?
    assert_equal "Test error", calculated_field.error_log["error"]
  end
  
  test "name must be unique per campaign" do
    account = accounts(:one)
    campaign = Campaign.create!(
      name: "Test Campaign",
      status: "active", 
      campaign_type: "ping_post",
      distribution_method: "highest_bid",
      vertical: verticals(:insurance),
      account: account
    )
    
    CalculatedField.create!(
      name: "Age",
      formula: "YEAR(NOW()) - YEAR(date_of_birth)",
      status: "active",
      campaign: campaign,
      account: account
    )
    
    duplicate = CalculatedField.new(
      name: "Age",
      formula: "YEAR(NOW()) - YEAR(date_of_birth)",
      status: "active",
      campaign: campaign,
      account: account
    )
    
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end
end
