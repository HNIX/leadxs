require "test_helper"

class BiddingApiTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @user = users(:one)
    @campaign = campaigns(:one)
    @distribution = distributions(:one)
    
    # Configure tenant for multi-tenancy
    ActsAsTenant.current_tenant = @account
    
    # Set up auth token
    @token = api_tokens(:one)
    @auth_header = "Bearer #{@token.token}"
    
    # Create test bid request
    @bid_request = create_test_bid_request
    
    # Set up stub responses
    stub_distribution_api_calls
  end
  
  teardown do
    ActsAsTenant.current_tenant = nil
  end
  
  test "creating a bid request via API" do
    post "/api/v1/bid_requests", 
      params: {
        campaign_id: @campaign.id,
        anonymized_data: {
          first_name: "John",
          email: "test@example.com",
          zip_code: "90210"
        },
        expires_in: 1800 # 30 minutes
      },
      headers: { "Authorization" => @auth_header },
      as: :json
    
    assert_response :success
    
    # Parse the response
    json_response = JSON.parse(response.body)
    assert_equal "pending", json_response["status"]
    assert_not_nil json_response["id"]
    assert_not_nil json_response["token"]
    
    # Save the bid request id and token for later tests
    @new_bid_request_id = json_response["id"]
    @new_bid_request_token = json_response["token"]
  end
  
  test "soliciting bids for a bid request via API" do
    # Create a bid in advance for this test
    @bid = create_test_bid
    
    # Make sure we have a pending bid request
    post "/api/v1/bid_requests/#{@bid_request.id}/solicit_bids",
      headers: { "Authorization" => @auth_header },
      as: :json
      
    assert_response :success
    
    # Parse the response
    json_response = JSON.parse(response.body)
    assert_equal "success", json_response["status"]
    assert_includes json_response, "bids_requested"
    
    # Now get the bid request to see if bids are returned
    get "/api/v1/bid_requests/#{@bid_request.id}",
      headers: { "Authorization" => @auth_header },
      as: :json
      
    assert_response :success
    
    # Parse the response
    json_response = JSON.parse(response.body)
    assert_includes json_response, "bids"
    assert json_response["bids"].length > 0, "Expected bids to be created"
  end
  
  test "accepting a bid via API" do
    # First, create a bid
    @bid = create_test_bid
    
    # Now accept the bid
    post "/api/v1/bid_requests/#{@bid_request.id}/bids/#{@bid.id}/accept",
      headers: { "Authorization" => @auth_header },
      as: :json
      
    assert_response :success
    
    # Parse the response
    json_response = JSON.parse(response.body)
    assert_equal "success", json_response["status"]
    
    # Get the bid request to verify the status
    get "/api/v1/bid_requests/#{@bid_request.id}",
      headers: { "Authorization" => @auth_header },
      as: :json
      
    assert_response :success
    
    # Parse the response
    json_response = JSON.parse(response.body)
    assert_equal "completed", json_response["status"]
    
    # Check the winning bid
    winning_bid = json_response["bids"].find { |b| b["status"] == "accepted" }
    assert_not_nil winning_bid
    assert_equal @bid.id.to_s, winning_bid["id"].to_s
  end
  
  test "getting analytics via API" do
    # Generate some sample analytics data
    generate_analytics_data
    
    # Get analytics for the account
    get "/api/v1/bid_analytics",
      params: { period_type: "daily" },
      headers: { "Authorization" => @auth_header },
      as: :json
      
    assert_response :success
    
    # Parse the response
    json_response = JSON.parse(response.body)
    assert_includes json_response, "analytics"
    assert json_response["analytics"].length > 0, "Expected analytics data to be returned"
    
    # Check specific metrics
    first_record = json_response["analytics"].first
    assert_includes first_record, "total_bids"
    assert_includes first_record, "accepted_bids"
    assert_includes first_record, "total_revenue"
  end
  
  test "fetching campaign-specific analytics" do
    # Generate campaign-specific analytics
    generate_analytics_data
    
    # Get analytics for a specific campaign
    get "/api/v1/campaigns/#{@campaign.id}/analytics",
      params: { period_type: "daily" },
      headers: { "Authorization" => @auth_header },
      as: :json
      
    assert_response :success
    
    # Parse the response
    json_response = JSON.parse(response.body)
    assert_includes json_response, "analytics"
    
    # Verify campaign-specific data
    first_record = json_response["analytics"].first
    assert_equal @campaign.id.to_s, first_record["campaign_id"].to_s
  end
  
  test "handling errors and edge cases" do
    # Test with invalid campaign ID
    post "/api/v1/bid_requests", 
      params: {
        campaign_id: 99999,
        anonymized_data: { first_name: "John" }
      },
      headers: { "Authorization" => @auth_header },
      as: :json
      
    assert_response :unprocessable_entity
    
    # Test with missing required fields
    post "/api/v1/bid_requests", 
      params: { anonymized_data: { first_name: "John" } },
      headers: { "Authorization" => @auth_header },
      as: :json
      
    assert_response :unprocessable_entity
    
    # Test with invalid token
    post "/api/v1/bid_requests", 
      params: {
        campaign_id: @campaign.id,
        anonymized_data: { first_name: "John" }
      },
      headers: { "Authorization" => "Bearer invalid_token" },
      as: :json
      
    assert_response :unauthorized
    
    # Test accepting an already accepted bid
    @bid = create_test_bid
    @bid.update(status: :accepted)
    
    post "/api/v1/bid_requests/#{@bid_request.id}/bids/#{@bid.id}/accept",
      headers: { "Authorization" => @auth_header },
      as: :json
      
    assert_response :unprocessable_entity
  end
  
  private
  
  def create_test_bid_request
    BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :pending,
      expires_at: 30.minutes.from_now,
      anonymized_data: { first_name: "John", zip_code: "90210" }
    )
  end
  
  def create_test_bid
    Bid.create!(
      account: @account,
      bid_request: @bid_request,
      distribution: @distribution,
      amount: 25.50,
      status: :pending
    )
  end
  
  def stub_distribution_api_calls
    # Stub external API calls to distributions
    stub_request(:post, /distribution\.example\.com/)
      .to_return(
        status: 200,
        body: {
          status: "success",
          bid_amount: 25.50,
          expiry: 10.minutes.from_now.iso8601,
          reference: "bid-#{SecureRandom.hex(8)}"
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
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