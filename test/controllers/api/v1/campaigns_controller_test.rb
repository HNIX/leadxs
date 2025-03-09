require "test_helper"

class Api::V1::CampaignsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @campaign = campaigns(:one)
    
    # Set up auth token
    @token = api_tokens(:one)
    @auth_header = "Bearer #{@token.token}"
    
    # Configure tenant for multi-tenancy
    ActsAsTenant.current_tenant = @account
    
    # Create test bid analytics data
    generate_analytics_data
  end
  
  teardown do
    ActsAsTenant.current_tenant = nil
  end
  
  test "should get campaign analytics" do
    get "/api/v1/campaigns/#{@campaign.id}/analytics", 
      headers: { "Authorization" => @auth_header },
      as: :json
    
    assert_response :success
    
    # Parse the response
    json_response = JSON.parse(response.body)
    assert_includes json_response, "campaign"
    assert_includes json_response, "analytics"
    
    # Check campaign data
    assert_equal @campaign.id, json_response["campaign"]["id"]
    assert_equal @campaign.name, json_response["campaign"]["name"]
    
    # Check analytics data
    assert_not_empty json_response["analytics"]
    
    first_analytics = json_response["analytics"].first
    assert_includes first_analytics, "total_bids"
    assert_includes first_analytics, "accepted_bids"
    assert_includes first_analytics, "rejected_bids"
    assert_includes first_analytics, "conversion_rate"
  end
  
  test "should return not found for nonexistent campaign" do
    get "/api/v1/campaigns/99999/analytics", 
      headers: { "Authorization" => @auth_header },
      as: :json
    
    assert_response :not_found
    
    json_response = JSON.parse(response.body)
    assert_equal "Campaign not found", json_response["error"]
  end
  
  test "should restrict access without proper authentication" do
    get "/api/v1/campaigns/#{@campaign.id}/analytics", as: :json
    
    assert_response :unauthorized
  end
  
  private
  
  def generate_analytics_data
    # Generate some sample analytics data for testing reports
    BidAnalyticSnapshot.create!(
      account: @account,
      period_start: 24.hours.ago,
      period_end: Time.current,
      period_type: :daily,
      total_bids: 100,
      accepted_bids: 75,
      rejected_bids: 20,
      expired_bids: 5,
      avg_bid_amount: 35.50,
      max_bid_amount: 55.00,
      min_bid_amount: 15.00,
      conversion_count: 50,
      total_revenue: 1775.00,
      metrics: { 
        response_rate: 95,
        avg_response_time: 2.5
      },
      campaign: @campaign
    )
  end
end