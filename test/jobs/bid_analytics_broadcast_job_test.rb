require "test_helper"

class BidAnalyticsBroadcastJobTest < ActiveJob::TestCase
  setup do
    @account = accounts(:one)
    @campaign = campaigns(:one)
    
    # Set the current tenant
    ActsAsTenant.current_tenant = @account
    
    # Create test data
    @snapshot = create_test_snapshot
    @bid_request = create_test_bid_request
    @bid = create_test_bid
  end
  
  teardown do
    ActsAsTenant.current_tenant = nil
  end
  
  test "job enqueues correctly" do
    assert_enqueued_with(job: BidAnalyticsBroadcastJob) do
      BidAnalyticsBroadcastJob.perform_later(@account.id, :snapshot_update, @snapshot)
    end
  end
  
  test "job performs snapshot update broadcast" do
    # Mock the BidAnalyticsChannel to capture the broadcast
    mock = Minitest::Mock.new
    mock.expect :broadcast_to, nil, [@account, Hash]
    
    # Replace the original broadcast_to method with our mock
    BidAnalyticsChannel.stub :broadcast_to, ->(account, data) { mock.broadcast_to(account, data) } do
      # Execute the job
      BidAnalyticsBroadcastJob.perform_now(@account.id, :snapshot_update, @snapshot)
    end
    
    # Verify the mock was called correctly
    assert_mock mock
  end
  
  test "job performs new bid broadcast" do
    # Mock the BidAnalyticsChannel to capture the broadcast
    mock = Minitest::Mock.new
    mock.expect :broadcast_to, nil, [@account, Hash]
    
    # Replace the original broadcast_to method with our mock
    BidAnalyticsChannel.stub :broadcast_to, ->(account, data) { mock.broadcast_to(account, data) } do
      # Execute the job
      BidAnalyticsBroadcastJob.perform_now(@account.id, :new_bid, @bid)
    end
    
    # Verify the mock was called correctly
    assert_mock mock
  end
  
  test "job handles invalid account gracefully" do
    # This should not raise an error
    assert_nothing_raised do
      BidAnalyticsBroadcastJob.perform_now(999999, :snapshot_update, @snapshot)
    end
  end
  
  test "job prepares metrics data correctly" do
    # Create a job instance
    job = BidAnalyticsBroadcastJob.new
    
    # Call the private method using send
    metrics_data = job.send(:prepare_metrics_data, @snapshot)
    
    # Verify the metrics are calculated correctly
    assert_equal @snapshot.total_bids, metrics_data[:total_bids]
    assert_equal @snapshot.accepted_bids, metrics_data[:accepted_bids]
    assert_equal @snapshot.rejected_bids, metrics_data[:rejected_bids]
    assert_equal @snapshot.expired_bids, metrics_data[:expired_bids]
    assert_equal @snapshot.avg_bid_amount.to_f.round(2), metrics_data[:avg_bid_amount]
    assert_equal @snapshot.max_bid_amount.to_f.round(2), metrics_data[:max_bid_amount]
    assert_equal @snapshot.min_bid_amount.to_f.round(2), metrics_data[:min_bid_amount]
    assert_equal @snapshot.conversion_count, metrics_data[:conversion_count]
    assert_equal @snapshot.total_revenue.to_f.round(2), metrics_data[:total_revenue]
    
    # Calculated metrics
    assert_equal ((@snapshot.accepted_bids.to_f / @snapshot.total_bids) * 100).round(2), metrics_data[:acceptance_rate]
    assert_equal ((@snapshot.conversion_count.to_f / @snapshot.total_bids) * 100).round(2), metrics_data[:conversion_rate]
    assert_equal (@snapshot.total_revenue.to_f / @snapshot.total_bids).round(2), metrics_data[:revenue_per_bid]
    assert_equal (@snapshot.total_revenue.to_f / @snapshot.accepted_bids).round(2), metrics_data[:revenue_per_accepted_bid]
    
    # Time series data
    assert_includes metrics_data, :bidVolumes
    assert_includes metrics_data, :conversionRates
  end
  
  test "job prepares bid data correctly" do
    # Create a job instance
    job = BidAnalyticsBroadcastJob.new
    
    # Call the private method using send
    bid_data = job.send(:prepare_bid_data, @bid)
    
    # Verify the bid data is prepared correctly
    assert_equal @bid.id, bid_data[:id]
    assert_equal @bid.amount.to_f, bid_data[:amount]
    assert_equal @bid.status, bid_data[:status]
    assert_equal @campaign.name, bid_data[:campaign]
    assert_equal @bid.distribution.name, bid_data[:distribution]
    assert_includes bid_data, :created_at
  end
  
  private
  
  def create_test_snapshot
    BidAnalyticSnapshot.create!(
      account: @account,
      period_start: 1.hour.ago,
      period_end: Time.current,
      period_type: :hourly,
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
      distribution: distributions(:one),
      amount: 25.50,
      status: :pending
    )
  end
end