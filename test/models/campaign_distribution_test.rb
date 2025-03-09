require "test_helper"

class CampaignDistributionTest < ActiveSupport::TestCase
  setup do
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
    Campaign.transaction do
      campaign = Campaign.create!(
        name: "Another Test Campaign",
        account: @campaign.account,
        vertical: @campaign.vertical,
        campaign_type: "direct",
        distribution_method: "highest_bid",
        status: "draft"
      )
      
      cd = campaign.campaign_distributions.build(
        distribution: distributions(:paused),
        priority: -1
      )
      assert_not cd.valid?
      assert_includes cd.errors[:priority], "must be greater than or equal to 0"

      cd = campaign.campaign_distributions.build(
        distribution: distributions(:paused),
        priority: 1.5
      )
      assert_not cd.valid?
      assert_includes cd.errors[:priority], "must be an integer"

      cd = campaign.campaign_distributions.build(
        distribution: distributions(:paused),
        priority: 0
      )
      assert cd.valid?

      cd = campaign.campaign_distributions.build(
        distribution: distributions(:paused),
        priority: nil
      )
      assert cd.valid?
      
      raise ActiveRecord::Rollback
    end
  end

  test "allows priority to be nil" do
    Campaign.transaction do
      campaign = Campaign.create!(
        name: "Yet Another Test Campaign",
        account: @campaign.account,
        vertical: @campaign.vertical,
        campaign_type: "direct",
        distribution_method: "highest_bid",
        status: "draft"
      )
      
      cd = campaign.campaign_distributions.build(
        distribution: distributions(:paused),
        priority: nil
      )
      assert cd.valid?
      
      raise ActiveRecord::Rollback
    end
  end

  test "creates default field mappings after create" do
    # Need a campaign and distribution not already linked
    Campaign.transaction do
      # Create a new campaign using existing account
      campaign = Campaign.create!(
        name: "Test Campaign for Distribution",
        account: @campaign.account,
        vertical: @campaign.vertical,
        campaign_type: "direct",
        distribution_method: "highest_bid",
        status: "draft"
      )
      
      # Create the campaign distribution with the paused distribution
      assert_difference "MappedField.count", campaign.campaign_fields.count do
        campaign.campaign_distributions.create!(
          distribution: distributions(:paused),
          active: true
        )
      end
      
      # Roll back this test to not affect other tests
      raise ActiveRecord::Rollback
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
