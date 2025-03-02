require "test_helper"

class CampaignsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @vertical = verticals(:home_services)
    @campaign = campaigns(:one)
    
    sign_in @user
    Current.account = @account
  end

  teardown do
    Current.reset
  end

  test "should get index" do
    get campaigns_url
    assert_response :success
  end

  test "should get new" do
    get new_campaign_url
    assert_response :success
  end

  test "should create campaign" do
    assert_difference("Campaign.count") do
      post campaigns_url, params: {
        campaign: {
          name: "New Test Campaign",
          status: "draft",
          campaign_type: "ping_post",
          description: "Description for test campaign",
          distribution_method: "highest_bid",
          vertical_id: @vertical.id
        }
      }
    end

    campaign = Campaign.last
    assert_redirected_to campaign_url(campaign)
    assert_equal "New Test Campaign", campaign.name
    assert_equal "draft", campaign.status
    assert_equal "ping_post", campaign.campaign_type
    assert_equal "highest_bid", campaign.distribution_method
    assert_equal @vertical.id, campaign.vertical_id
  end

  test "should create campaign with scheduling" do
    assert_difference("Campaign.count") do
      post campaigns_url, params: {
        campaign: {
          name: "Scheduled Campaign",
          status: "draft",
          campaign_type: "ping_post",
          description: "Campaign with schedule",
          distribution_method: "highest_bid",
          vertical_id: @vertical.id,
          distribution_schedule_enabled: "1",
          distribution_schedule_days: ["monday", "wednesday", "friday"],
          distribution_schedule_start_time: "09:00",
          distribution_schedule_end_time: "17:00"
        }
      }
    end

    campaign = Campaign.last
    assert_redirected_to campaign_url(campaign)
    assert campaign.distribution_schedule_enabled
    assert_equal ["monday", "wednesday", "friday"], campaign.distribution_schedule_days
  end

  test "should not create campaign with invalid attributes" do
    assert_no_difference("Campaign.count") do
      post campaigns_url, params: {
        campaign: {
          name: "",
          status: "invalid_status",
          campaign_type: "invalid_type",
          vertical_id: @vertical.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should show campaign" do
    get campaign_url(@campaign)
    assert_response :success
  end

  test "should get edit" do
    get edit_campaign_url(@campaign)
    assert_response :success
  end

  test "should update campaign" do
    patch campaign_url(@campaign), params: {
      campaign: {
        name: "Updated Campaign Name",
        description: "Updated description"
      }
    }
    
    @campaign.reload
    assert_redirected_to campaign_url(@campaign)
    assert_equal "Updated Campaign Name", @campaign.name
    assert_equal "Updated description", @campaign.description
  end

  test "should not update campaign with invalid attributes" do
    patch campaign_url(@campaign), params: {
      campaign: {
        name: "",
        status: "invalid_status"
      }
    }
    
    assert_response :unprocessable_entity
  end

  test "should destroy campaign" do
    assert_difference("Campaign.count", -1) do
      delete campaign_url(@campaign)
    end

    assert_redirected_to campaigns_url
  end
end
