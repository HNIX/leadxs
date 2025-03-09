require "application_system_test_case"

class BiddingWorkflowTest < ApplicationSystemTestCase
  setup do
    @account = accounts(:one)
    @user = users(:one)
    @campaign = campaigns(:one)
    @distribution = distributions(:one)
    
    # Configure tenant for multi-tenancy
    ActsAsTenant.current_tenant = @account
    
    # Log in as a user
    login_as @user
    
    # Set up stub responses for API calls
    stub_distribution_api_calls
  end
  
  teardown do
    ActsAsTenant.current_tenant = nil
  end
  
  test "complete bidding workflow from dashboard to bid acceptance" do
    # 1. Navigate to the bidding dashboard
    visit dashboard_bid_requests_path
    assert_text "Bid Requests Dashboard"
    
    # 2. Create a new bid request
    click_on "New Bid Request"
    assert_text "New Bid Request"
    
    # 3. Fill out the form
    select @campaign.name, from: "Campaign"
    fill_in "Expires at", with: 30.minutes.from_now.strftime("%Y-%m-%d %H:%M:%S")
    
    # Add some anonymized data fields
    fill_in "First Name", with: "John"
    fill_in "Email", with: "test@example.com"
    fill_in "Zip Code", with: "90210"
    
    # 4. Submit the form
    click_on "Create Bid Request"
    
    # 5. Verify we're on the bid request page
    assert_text "Bid request was successfully created"
    assert_text "Status: pending"
    
    # 6. Trigger bid solicitation
    click_on "Request Bids"
    
    # Wait for bids to be processed
    sleep 2
    
    # 7. Refresh to see bids
    visit current_path
    
    # 8. Verify bids have been received
    assert_text "Bids received"
    
    # 9. Accept a bid
    within ".bid-item:first-child" do
      click_on "Accept"
    end
    
    # 10. Verify bid has been accepted
    assert_text "Bid was successfully accepted"
    assert_text "Status: completed"
    
    # 11. Navigate to analytics dashboard
    click_on "Analytics Dashboard"
    assert_text "Bid Analytics Dashboard"
    
    # 12. Verify analytics is displayed
    assert_selector ".card", minimum: 4
    
    # 13. Navigate to real-time dashboard
    click_on "Real-time Dashboard"
    assert_text "Real-Time Bid Dashboard"
    
    # 14. Verify real-time charts are present
    assert_selector "canvas", minimum: 2
  end
  
  test "filtering and managing bid requests" do
    # Create a few bid requests for testing
    create_test_bid_requests
    
    # 1. Navigate to the bid requests index
    visit bid_requests_path
    assert_text "Bid Requests"
    
    # 2. Filter by campaign
    select @campaign.name, from: "campaign_id"
    click_on "Filter"
    
    # 3. Verify filtered results
    assert_text @campaign.name
    
    # 4. Sort by created date
    click_on "Created At"
    
    # 5. Check bid request details
    first(".bid-request-item").click_on "View"
    assert_text "Bid Request Details"
    
    # 6. Expire a pending bid request
    if has_button?("Expire")
      click_on "Expire"
      assert_text "Status: expired"
    end
    
    # 7. Go back to index
    click_on "Back to Bid Requests"
    assert_text "Bid Requests"
  end
  
  test "viewing detailed reports and analytics" do
    # Ensure we have some analytics data
    generate_analytics_data
    
    # 1. Navigate to the reports page
    visit bid_reports_path
    assert_text "Bid Performance Reports"
    
    # 2. Select different time periods
    select "Daily", from: "period_type"
    click_on "Apply Filter"
    
    # 3. Verify report content
    assert_selector ".chart", minimum: 1
    
    # 4. Navigate to campaign specific report
    click_on "Campaign Reports"
    select @campaign.name, from: "campaign_id"
    click_on "View Report"
    
    # 5. Verify campaign specific data
    assert_text @campaign.name
    assert_selector ".chart", minimum: 1
  end
  
  test "real-time dashboard functionality" do
    # 1. Navigate to the real-time dashboard
    visit real_time_bid_dashboard_path
    assert_text "Real-Time Bid Dashboard"
    
    # 2. Verify real-time components are present
    assert_selector "#realtime-bid-counter"
    assert_selector "canvas#realtimeBidVolumeChart"
    assert_selector "canvas#realtimeAcceptanceRateChart"
    assert_selector "#bid-live-feed"
    
    # 3. Verify data is loaded or placeholder is shown
    assert_selector ".card", minimum: 4
    
    # 4. Verify navigation between dashboards works
    click_on "Analytics Dashboard"
    assert_text "Bid Analytics Dashboard"
    
    click_on "Reports"
    assert_text "Bid Performance Reports"
    
    click_on "Bid Requests"
    assert_text "Bid Requests Dashboard"
  end
  
  private
  
  def stub_distribution_api_calls
    # Stub external API calls to distributions
    stub_request(:post, /distribution\.example\.com/)
      .to_return(
        status: 200,
        body: {
          status: "success",
          bid: {
            amount: 25.50,
            expiry: 10.minutes.from_now.iso8601,
            reference: "bid-#{SecureRandom.hex(8)}"
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
  def create_test_bid_requests
    # Create a few bid requests with different statuses
    @bid_request_pending = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :pending,
      expires_at: 30.minutes.from_now,
      anonymized_data: { first_name: "John", zip_code: "90210" }
    )
    
    @bid_request_completed = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :completed,
      expires_at: 30.minutes.from_now,
      anonymized_data: { first_name: "Jane", zip_code: "10001" }
    )
    
    @bid_request_expired = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :expired,
      expires_at: 5.minutes.ago,
      anonymized_data: { first_name: "Bob", zip_code: "60601" }
    )
    
    # Create bids for the completed request
    @bid = Bid.create!(
      account: @account,
      bid_request: @bid_request_completed,
      distribution: @distribution,
      amount: 25.50,
      status: :accepted
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