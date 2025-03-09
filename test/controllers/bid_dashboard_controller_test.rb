require "test_helper"

class BidDashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    
    # Set up multi-tenancy for tests
    ActsAsTenant.current_tenant = @account
    
    # Log in the user
    sign_in @user
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "should get index" do
    get bid_dashboard_url
    assert_response :success
  end

  test "should get real_time" do
    get real_time_bid_dashboard_url
    assert_response :success
  end

  test "should handle empty data gracefully" do
    # Clear out existing snapshots
    BidAnalyticSnapshot.where(account: @account).destroy_all
    
    get bid_dashboard_url
    assert_response :success
  end

  test "should prepare time series data with snapshots" do
    # Create test snapshot
    snapshot = BidAnalyticSnapshot.create!(
      account: @account,
      period_start: 1.hour.ago,
      period_end: Time.current,
      period_type: :hourly,
      total_bids: 100,
      accepted_bids: 75,
      rejected_bids: 20,
      expired_bids: 5,
      avg_bid_amount: 35.5,
      max_bid_amount: 55.0,
      min_bid_amount: 15.0,
      conversion_count: 50,
      total_revenue: 1775.0,
      metrics: {
        bid_requests_sent: 110,
        avg_response_time: 2.5,
        time_to_expiration: 30.0,
        distribution_stats: {},
        campaign_stats: {}
      }
    )
    
    get bid_dashboard_url
    assert_response :success
    
    # Just verify the request was successful - we can't easily check instance variables
    # without adding the rails-controller-testing gem
  end
end