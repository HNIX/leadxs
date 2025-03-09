require "application_system_test_case"

class BiddingDashboardsTest < ApplicationSystemTestCase
  setup do
    @account = accounts(:one)
    @user = users(:one)
    @campaign = campaigns(:one)
    @distribution = distributions(:one)
    
    # Configure tenant for multi-tenancy
    ActsAsTenant.current_tenant = @account
    
    # Log in as a user
    login_as @user
    
    # Generate test data
    create_test_data
  end
  
  teardown do
    ActsAsTenant.current_tenant = nil
  end
  
  test "analytics dashboard displays correct metrics and charts" do
    # Visit the analytics dashboard
    visit bid_dashboard_path
    assert_text "Bid Analytics Dashboard"
    
    # Verify summary cards are displayed
    assert_selector ".card", minimum: 4
    assert_text "Total Bids"
    assert_text "Acceptance Rate"
    assert_text "Total Revenue"
    assert_text "Avg Bid Amount"
    
    # Verify charts are rendered
    assert_selector "canvas#bidVolumeChart"
    assert_selector "canvas#acceptanceRateChart"
    assert_selector "canvas#revenueChart"
    assert_selector "canvas#avgBidChart"
    
    # Verify campaign performance table
    assert_text "Campaign Performance"
    assert_selector "table"
    assert_text @campaign.name
  end
  
  test "real-time dashboard renders live components" do
    # Visit the real-time dashboard
    visit real_time_bid_dashboard_path
    assert_text "Real-Time Bid Dashboard"
    
    # Verify real-time metrics cards
    assert_selector ".card", minimum: 4
    assert_text "Bids (Last Hour)"
    assert_text "Active Campaigns"
    assert_text "Current Acceptance Rate"
    assert_text "Real-time Bid Count"
    
    # Verify real-time charts are rendered
    assert_selector "canvas#realtimeBidVolumeChart"
    assert_selector "canvas#realtimeAcceptanceRateChart"
    
    # Check live bid feed
    assert_selector "#bid-live-feed"
    
    # Verify top campaigns section
    assert_text "Top Campaigns"
    within "#top-campaigns" do
      assert_text @campaign.name if @campaign.present?
    end
  end
  
  test "navigation between dashboards works correctly" do
    # Start at the main dashboard
    visit dashboard_path
    assert_text "Dashboard"
    
    # Navigate to bid requests dashboard
    click_on "Bid Requests"
    assert_text "Bid Requests Dashboard"
    
    # Navigate to analytics dashboard
    click_on "Analytics Dashboard"
    assert_text "Bid Analytics Dashboard"
    
    # Navigate to real-time dashboard
    click_on "Real-time Dashboard"
    assert_text "Real-Time Bid Dashboard"
    
    # Navigate to reports
    click_on "Reports"
    assert_text "Bid Performance Reports"
    
    # Return to bid requests dashboard
    click_on "Bid Requests"
    assert_text "Bid Requests Dashboard"
  end
  
  test "dashboard date filtering works" do
    # Visit the reports page
    visit bid_reports_path
    assert_text "Bid Performance Reports"
    
    # Test period selection
    select "Daily", from: "period_type"
    click_on "Apply Filter"
    
    # Check that chart is updated
    assert_selector ".chart", minimum: 1
    
    # Test date range selection
    fill_in "start_date", with: 7.days.ago.strftime("%Y-%m-%d")
    fill_in "end_date", with: Time.current.strftime("%Y-%m-%d")
    click_on "Apply Filter"
    
    # Check that chart is updated
    assert_selector ".chart", minimum: 1
  end
  
  test "campaign-specific analytics display correctly" do
    # Visit the campaign report page
    visit campaign_bid_report_path(@campaign)
    assert_text "Bid Performance for #{@campaign.name}"
    
    # Verify campaign metrics
    assert_selector ".card", minimum: 4
    
    # Verify charts are rendered
    assert_selector "canvas", minimum: 2
    
    # Verify we have time series data
    assert_text "Performance Over Time"
  end
  
  test "responding to real-time updates" do
    # Visit the real-time dashboard
    visit real_time_bid_dashboard_path
    assert_text "Real-Time Bid Dashboard"
    
    # Get current counters
    bid_counter_value = find("#realtime-bid-counter").text.to_i
    
    # Simulate a new bid coming in by running JavaScript
    page.execute_script <<-JS
      const newBid = {
        type: 'new_bid',
        bid: {
          id: '123',
          amount: 45.5,
          status: 'accepted',
          campaign: 'Test Campaign',
          created_at: new Date().toISOString()
        }
      };
      document.dispatchEvent(new CustomEvent('bid_received', { detail: newBid }));
    JS
    
    # Check that the counter incremented
    sleep 1
    assert_not_equal bid_counter_value, find("#realtime-bid-counter").text.to_i
  end
  
  private
  
  def create_test_data
    # Create bid requests
    3.times do |i|
      create_bid_request_with_bids(i)
    end
    
    # Generate analytics data
    generate_hourly_snapshots
    generate_daily_snapshots
    generate_weekly_snapshots
  end
  
  def create_bid_request_with_bids(index)
    # Create a bid request
    bid_request = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: [:pending, :completed, :expired].sample,
      expires_at: 30.minutes.from_now,
      anonymized_data: { 
        first_name: "Person#{index}", 
        email: "person#{index}@example.com",
        zip_code: "9#{index}210"
      }
    )
    
    # Create a bid for this request if it's not expired
    unless bid_request.expired?
      Bid.create!(
        account: @account,
        bid_request: bid_request,
        distribution: @distribution,
        amount: (25 + rand(50)).to_f,
        status: bid_request.completed? ? :accepted : :pending
      )
    end
    
    bid_request
  end
  
  def generate_hourly_snapshots
    24.times do |i|
      BidAnalyticSnapshot.create!(
        account: @account,
        period_start: (23-i).hours.ago.beginning_of_hour,
        period_end: (23-i).hours.ago.end_of_hour,
        period_type: :hourly,
        total_bids: 10 + rand(20),
        accepted_bids: 5 + rand(10),
        rejected_bids: 2 + rand(5),
        expired_bids: 1 + rand(3),
        avg_bid_amount: 20 + rand(30),
        max_bid_amount: 50 + rand(50),
        min_bid_amount: 10 + rand(10),
        conversion_count: 3 + rand(7),
        total_revenue: 100 + rand(500),
        metrics: { 
          response_rate: 85 + rand(15),
          avg_response_time: 1 + rand(5)
        },
        campaign: @campaign
      )
    end
  end
  
  def generate_daily_snapshots
    30.times do |i|
      BidAnalyticSnapshot.create!(
        account: @account,
        period_start: (29-i).days.ago.beginning_of_day,
        period_end: (29-i).days.ago.end_of_day,
        period_type: :daily,
        total_bids: 50 + rand(100),
        accepted_bids: 30 + rand(50),
        rejected_bids: 10 + rand(20),
        expired_bids: 5 + rand(10),
        avg_bid_amount: 25 + rand(25),
        max_bid_amount: 50 + rand(100),
        min_bid_amount: 10 + rand(15),
        conversion_count: 15 + rand(30),
        total_revenue: 500 + rand(2000),
        metrics: { 
          response_rate: 85 + rand(15),
          avg_response_time: 1 + rand(5)
        },
        campaign: @campaign
      )
    end
  end
  
  def generate_weekly_snapshots
    12.times do |i|
      BidAnalyticSnapshot.create!(
        account: @account,
        period_start: (11-i).weeks.ago.beginning_of_week,
        period_end: (11-i).weeks.ago.end_of_week,
        period_type: :weekly,
        total_bids: 300 + rand(500),
        accepted_bids: 200 + rand(300),
        rejected_bids: 50 + rand(100),
        expired_bids: 25 + rand(50),
        avg_bid_amount: 25 + rand(25),
        max_bid_amount: 75 + rand(100),
        min_bid_amount: 10 + rand(15),
        conversion_count: 100 + rand(200),
        total_revenue: 3000 + rand(10000),
        metrics: { 
          response_rate: 85 + rand(15),
          avg_response_time: 1 + rand(5)
        },
        campaign: @campaign
      )
    end
  end
end