require "test_helper"

class CampaignTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @vertical = verticals(:home_services)
  end

  test "should be valid with required attributes" do
    campaign = Campaign.new(
      account: @account,
      vertical: @vertical,
      name: "Test Campaign",
      status: "draft",
      campaign_type: "ping_post",
      distribution_method: "highest_bid"
    )
    assert campaign.valid?
  end

  test "should require name" do
    campaign = Campaign.new(
      account: @account,
      vertical: @vertical,
      status: "draft",
      campaign_type: "ping_post",
      distribution_method: "highest_bid"
    )
    assert_not campaign.valid?
    assert_includes campaign.errors[:name], "can't be blank"
  end

  test "should require status" do
    campaign = Campaign.new(
      account: @account,
      vertical: @vertical,
      name: "Test Campaign",
      campaign_type: "ping_post",
      distribution_method: "highest_bid"
    )
    assert_not campaign.valid?
    assert_includes campaign.errors[:status], "can't be blank"
  end

  test "should require valid status" do
    campaign = Campaign.new(
      account: @account,
      vertical: @vertical,
      name: "Test Campaign",
      status: "invalid_status",
      campaign_type: "ping_post",
      distribution_method: "highest_bid"
    )
    assert_not campaign.valid?
    assert_includes campaign.errors[:status], "is not included in the list"
  end

  test "should require campaign_type" do
    campaign = Campaign.new(
      account: @account,
      vertical: @vertical,
      name: "Test Campaign",
      status: "draft",
      distribution_method: "highest_bid"
    )
    assert_not campaign.valid?
    assert_includes campaign.errors[:campaign_type], "can't be blank"
  end

  test "should require valid campaign_type" do
    campaign = Campaign.new(
      account: @account,
      vertical: @vertical,
      name: "Test Campaign",
      status: "draft",
      campaign_type: "invalid_type",
      distribution_method: "highest_bid"
    )
    assert_not campaign.valid?
    assert_includes campaign.errors[:campaign_type], "is not included in the list"
  end

  test "should require distribution_method" do
    campaign = Campaign.new(
      account: @account,
      vertical: @vertical,
      name: "Test Campaign",
      status: "draft",
      campaign_type: "ping_post"
    )
    assert_not campaign.valid?
    assert_includes campaign.errors[:distribution_method], "can't be blank"
  end

  test "should require valid distribution_method" do
    campaign = Campaign.new(
      account: @account,
      vertical: @vertical,
      name: "Test Campaign",
      status: "draft",
      campaign_type: "ping_post",
      distribution_method: "invalid_method"
    )
    assert_not campaign.valid?
    assert_includes campaign.errors[:distribution_method], "is not included in the list"
  end

  test "should require schedule details when scheduling is enabled" do
    campaign = Campaign.new(
      account: @account,
      vertical: @vertical,
      name: "Test Campaign",
      status: "draft",
      campaign_type: "ping_post",
      distribution_method: "highest_bid",
      distribution_schedule_enabled: true
    )
    assert_not campaign.valid?
    assert_includes campaign.errors[:distribution_schedule_days], "can't be blank"
    assert_includes campaign.errors[:distribution_schedule_start_time], "can't be blank"
    assert_includes campaign.errors[:distribution_schedule_end_time], "can't be blank"
  end

  test "should validate end time is after start time" do
    start_time = Time.current
    end_time = start_time - 1.hour
    
    campaign = Campaign.new(
      account: @account,
      vertical: @vertical,
      name: "Test Campaign",
      status: "draft",
      campaign_type: "ping_post",
      distribution_method: "highest_bid",
      distribution_schedule_enabled: true,
      distribution_schedule_days: ["monday", "wednesday", "friday"],
      distribution_schedule_start_time: start_time,
      distribution_schedule_end_time: end_time
    )
    
    assert_not campaign.valid?
    assert_includes campaign.errors[:distribution_schedule_end_time], "must be after the start time"
  end

  test "should store and retrieve distribution_schedule_days as JSON" do
    # Temporarily disable callbacks to avoid field generation issues
    Campaign.skip_callback(:create, :after, :generate_fields_from_vertical)
    
    days = ["monday", "wednesday", "friday"]
    
    campaign = Campaign.create!(
      account: @account,
      vertical: @vertical,
      name: "Test Campaign",
      status: "draft",
      campaign_type: "ping_post",
      distribution_method: "highest_bid",
      distribution_schedule_enabled: true,
      distribution_schedule_days: days,
      distribution_schedule_start_time: Time.current,
      distribution_schedule_end_time: Time.current + 8.hours
    )
    
    # Reload to ensure persistence
    campaign.reload
    
    assert_equal days, campaign.distribution_schedule_days
    
    # Re-enable callback
    Campaign.set_callback(:create, :after, :generate_fields_from_vertical)
  end

  test "should generate campaign fields from vertical after creation" do
    campaign = Campaign.new(
      account: @account,
      vertical: @vertical,
      name: "Test Campaign",
      status: "draft",
      campaign_type: "ping_post",
      distribution_method: "highest_bid"
    )
    
    # Ensure the after_create callback is triggered to generate fields
    assert_difference('CampaignField.count', @vertical.vertical_fields.count) do
      campaign.save!
    end
    
    # Vertical should have fields
    assert @vertical.vertical_fields.count > 0
    
    # Campaign should have fields generated from vertical
    assert campaign.campaign_fields.count > 0
    assert_equal @vertical.vertical_fields.count, campaign.campaign_fields.count
  end

  test "should assign correct field attributes when generating from vertical" do
    # Find a vertical with a complex field that has list values
    vertical_with_list = verticals(:home_services)
    list_field = vertical_fields(:list_field)
    
    # Create campaign and let callbacks handle field generation
    campaign = Campaign.create!(
      account: @account,
      vertical: vertical_with_list,
      name: "Test Campaign",
      status: "draft",
      campaign_type: "ping_post",
      distribution_method: "highest_bid"
    )
    
    # Find corresponding campaign field
    campaign_field = campaign.campaign_fields.find_by(name: list_field.name)
    
    # Verify attributes were correctly copied
    assert_equal list_field.name, campaign_field.name
    assert_equal list_field.label, campaign_field.label
    assert_equal list_field.data_type, campaign_field.data_type
    assert_equal list_field.position, campaign_field.position
    assert_equal list_field.required, campaign_field.required
    assert_equal list_field.is_pii, campaign_field.is_pii
    assert_equal list_field.ping_required, campaign_field.ping_required
    assert_equal list_field.post_required, campaign_field.post_required
    assert_equal list_field.post_only, campaign_field.post_only
    assert_equal list_field.hide, campaign_field.hide
    assert_equal list_field.value_acceptance, campaign_field.value_acceptance
    
    # Check that list values were copied if field has them
    if list_field.value_acceptance == "list"
      assert_equal list_field.list_values.count, campaign_field.list_values.count
    end
  end
end
