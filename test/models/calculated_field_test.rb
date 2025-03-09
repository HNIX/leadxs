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
    ActsAsTenant.with_tenant(accounts(:one)) do
      campaign = Campaign.create!(
        name: "Test Campaign",
        status: "active", 
        campaign_type: "ping_post",
        distribution_method: "highest_bid",
        vertical: verticals(:insurance),
        account: accounts(:one)
      )
      
      # Create another campaign to test cross-campaign validation
      campaign2 = Campaign.create!(
        name: "Second Test Campaign",
        status: "active", 
        campaign_type: "ping_post",
        distribution_method: "highest_bid",
        vertical: verticals(:insurance),
        account: accounts(:one)
      )
      
      # Create initial calculated field
      cf = CalculatedField.create!(
        name: "Age",
        formula: "YEAR(NOW()) - YEAR(date_of_birth)",
        status: "active",
        campaign: campaign,
        account: accounts(:one)
      )
      
      # Create duplicate with same name in the same campaign
      duplicate = CalculatedField.new(
        name: "Age",
        formula: "YEAR(NOW()) - YEAR(date_of_birth)",
        status: "active",
        campaign: campaign,
        account: accounts(:one)
      )
      
      # This should fail - same name, same campaign
      assert_not duplicate.valid?
      assert_includes duplicate.errors[:name], "has already been taken"
      
      # Create calculated field with same name but in a different campaign - should be valid
      different_campaign = CalculatedField.new(
        name: "Age",
        formula: "YEAR(NOW()) - YEAR(date_of_birth)",
        status: "active",
        campaign: campaign2,
        account: accounts(:one)
      )
      
      # This should be valid - same name but different campaign
      assert different_campaign.valid?
      
      # Verify DB constraint works too - we need to do this in a separate transaction
      # First, let's check if a record with the same name actually exists
      existing_count = CalculatedField.where(campaign_id: campaign.id, name: "Age").count
      assert_equal 1, existing_count, "Should have exactly one record with this name in this campaign"
      
      # Use a separate test connection to verify the database constraint without affecting our main test transaction
      test_connection = ActiveRecord::Base.connection.raw_connection
      begin
        # Try inserting a duplicate directly at the PostgreSQL level
        insert_result = test_connection.exec_params(
          "INSERT INTO calculated_fields 
           (name, formula, status, campaign_id, account_id, created_at, updated_at)
           VALUES 
           ($1, $2, $3, $4, $5, NOW(), NOW())
           RETURNING id",
          ['Age', 'YEAR(NOW()) - YEAR(date_of_birth)', 'active', campaign.id, accounts(:one).id]
        )
        # If we get here, the constraint didn't work
        flunk "Database constraint failed to prevent duplicate insertion"
      rescue PG::UniqueViolation => e
        # This is expected - verify the error message
        assert_match(/unique constraint/, e.message.downcase)
      end
    end
  end
end
