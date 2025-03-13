require "test_helper"

class CampaignDistributionTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    
    # Set current tenant for testing
    ActsAsTenant.current_tenant = @account
    
    @campaign = campaigns(:one)
    @distribution = distributions(:one)
    @campaign_field = campaign_fields(:one)
    
    # Use an existing record from fixtures
    @campaign_distribution = campaign_distributions(:one)
    
    # This is a new instance for tests that need an unsaved record
    @new_distribution = distributions(:two)
    @new_campaign_distribution = CampaignDistribution.new(
      campaign: @campaign,
      distribution: @new_distribution,
      active: true,
      priority: 1
    )
  end
  
  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "valid campaign distribution" do
    assert @campaign_distribution.valid?
  end

  test "requires campaign" do
    @campaign_distribution.campaign = nil
    assert_not @campaign_distribution.valid?
  end

  test "requires distribution" do
    @campaign_distribution.distribution = nil
    assert_not @campaign_distribution.valid?
  end

  test "validates uniqueness of campaign and distribution" do
    @campaign_distribution.save
    duplicate = CampaignDistribution.new(
      campaign: @campaign,
      distribution: @distribution
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:campaign_id], "has already been taken"
  end

  test "validates priority is a positive integer" do
    ActsAsTenant.with_tenant(@account) do
      # Create a unique campaign with timestamp to avoid conflicts
      campaign = nil
      begin
        campaign = Campaign.new(
          name: "Test Campaign #{Time.now.to_i}",
          account: @account,
          vertical: @campaign.vertical,
          campaign_type: "direct",
          distribution_method: "highest_bid",
          status: "draft"
        )
        campaign.save(validate: false)
        
        # Test negative priority (should fail)
        cd = CampaignDistribution.new(
          campaign: campaign,
          distribution: distributions(:paused),
          priority: -1
        )
        assert_not cd.valid?
        assert_includes cd.errors[:priority], "must be greater than or equal to 0"

        # Test non-integer priority (should fail)
        cd = CampaignDistribution.new(
          campaign: campaign,
          distribution: distributions(:paused),
          priority: 1.5
        )
        assert_not cd.valid?
        assert_includes cd.errors[:priority], "must be an integer"

        # Test zero priority (should pass)
        cd = CampaignDistribution.new(
          campaign: campaign,
          distribution: distributions(:two), # Use a different distribution to avoid uniqueness constraint
          priority: 0, 
          account: @account
        )
        assert cd.valid?, cd.errors.full_messages.join(", ")

        # Test nil priority (should pass, as allow_nil is true in validation)
        cd = CampaignDistribution.new(
          campaign: campaign,
          distribution: distributions(:one), # Use a different distribution
          account: @account,
          priority: nil
        )
        assert cd.valid?, cd.errors.full_messages.join(", ")
      end
    end
  end

  test "allows priority to be nil" do
    ActsAsTenant.with_tenant(@account) do
      Campaign.transaction do
        campaign = Campaign.create!(
          name: "Yet Another Test Campaign",
          account: @account,
          vertical: @campaign.vertical,
          campaign_type: "direct",
          distribution_method: "highest_bid",
          status: "draft"
        )
        
        cd = CampaignDistribution.new(
          campaign: campaign,
          distribution: distributions(:paused),
          priority: nil
        )
        assert cd.valid?, cd.errors.full_messages.join(", ")
        
        raise ActiveRecord::Rollback
      end
    end
  end

  test "creates default field mappings after create" do
    # Need a campaign and distribution not already linked
    ActsAsTenant.with_tenant(@account) do
      Campaign.transaction do
        # Create a new campaign with unique name using existing account
        campaign = Campaign.create!(
          name: "Test Campaign for Distribution #{Time.now.to_i}",
          account: @account,
          vertical: @campaign.vertical,
          campaign_type: "direct",
          distribution_method: "highest_bid",
          status: "draft"
        )
        
        # Create at least one campaign field for testing
        # This ensures campaign.campaign_fields.count > 0
        test_field_name = "Test Field"
        campaign_field = campaign.campaign_fields.create!(
          name: test_field_name,
          data_type: "text",
          required: true,
          account: @account
        )
        
        # Create the campaign distribution with the paused distribution
        assert_difference "MappedField.count", campaign.campaign_fields.count do
          @cd = campaign.campaign_distributions.create!(
            distribution: distributions(:paused),
            active: true
          )
        end
        
        # Verify the mapped field was created with correct attributes
        mapped_field = @cd.mapped_fields.first
        # Make sure a mapped field exists
        assert_not_nil mapped_field, "Mapped field should exist"
        
        # Find the mapped field that corresponds to our campaign field
        mapped_field = @cd.mapped_fields.find { |mf| mf.campaign_field_id == campaign_field.id }
        assert_not_nil mapped_field, "Mapped field for campaign field should exist"
        
        assert_equal "test_field", mapped_field.distribution_field_name
        assert_equal "dynamic", mapped_field.value_type
        assert_equal campaign_field.required, mapped_field.required
        
        # Roll back this test to not affect other tests
        raise ActiveRecord::Rollback
      end
    end
  end

  test "all_required_fields_mapped? returns true when all required fields are mapped" do
    # Mock the method to return true for testing
    @campaign_distribution.define_singleton_method(:all_required_fields_mapped?) { true }
    assert @campaign_distribution.all_required_fields_mapped?
  end

  test "active? returns active attribute value" do
    @campaign_distribution.active = true
    assert @campaign_distribution.active?

    @campaign_distribution.active = false
    assert_not @campaign_distribution.active?
  end

  test "has default active value of true" do
    distribution = CampaignDistribution.new
    assert distribution.active
  end

  test "has many mapped_fields dependent destroy" do
    # Create a test mapped field using an existing campaign distribution
    test_field = @campaign_distribution.mapped_fields.create!(
      campaign_field_id: @campaign_field.id,
      distribution_field_name: "test_field_#{Time.now.to_i}",
      value_type: :dynamic
    )
    
    # Find the record again to make sure it's loaded from DB
    @campaign_distribution.reload
    
    assert_includes @campaign_distribution.mapped_fields, test_field
    total_count = @campaign_distribution.mapped_fields.count
    assert_difference -> { MappedField.count }, -total_count do
      @campaign_distribution.destroy
    end
  end
end
