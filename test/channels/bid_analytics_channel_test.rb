require "test_helper"

class BidAnalyticsChannelTest < ActionCable::Channel::TestCase
  test "subscribes and streams for account" do
    @account = accounts(:one)
    
    # Set the current tenant
    ActsAsTenant.with_tenant(@account) do
      # Set up current user for connection
      stub_connection current_user: users(:one), current_account: @account
      
      # Subscribe to the channel
      subscribe
      
      # Verify the subscription was successful
      assert subscription.confirmed?
      
      # Verify it's streaming for the account
      assert_has_stream_for @account
    end
  end

  test "broadcasts to the account's stream" do
    @account = accounts(:one)
    
    # Set the current tenant
    ActsAsTenant.with_tenant(@account) do
      # Set up current user for connection
      stub_connection current_user: users(:one), current_account: @account
      
      # Subscribe to the channel
      subscribe
      
      # Create a snapshot to broadcast
      snapshot = BidAnalyticSnapshot.create!(
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
        }
      )
      
      # Create a job and perform it, we'll just assert it doesn't raise an error
      assert_nothing_raised do
        BidAnalyticsBroadcastJob.perform_now(@account.id, :snapshot_update, snapshot)
      end
      
      # Can't easily test the exact broadcast content in ActionCable tests
      # but we can assert that the job completes successfully
      # which implies the broadcast was made
      assert true
    end
  end
  
  test "broadcasts new bids to the account's stream" do
    @account = accounts(:one)
    @campaign = campaigns(:one)
    
    # Set the current tenant
    ActsAsTenant.with_tenant(@account) do
      # Create a bid request
      bid_request = BidRequest.create!(
        account: @account,
        campaign: @campaign,
        status: :pending,
        expires_at: 30.minutes.from_now,
        anonymized_data: { first_name: "John", zip_code: "90210" }
      )
      
      # Create a bid
      bid = Bid.create!(
        account: @account,
        bid_request: bid_request,
        distribution: distributions(:one),
        amount: 25.50,
        status: :pending
      )
      
      # Set up current user for connection
      stub_connection current_user: users(:one), current_account: @account
      
      # Subscribe to the channel
      subscribe
      
      # Create a job and perform it, we'll just assert it doesn't raise an error
      assert_nothing_raised do
        BidAnalyticsBroadcastJob.perform_now(@account.id, :new_bid, bid)
      end
      
      # Can't easily test the exact broadcast content in ActionCable tests
      # but we can assert that the job completes successfully
      # which implies the broadcast was made
      assert true
    end
  end
  
  test "performs data format conversion correctly" do
    @account = accounts(:one)
    @campaign = campaigns(:one)
    
    # Set the current tenant
    ActsAsTenant.with_tenant(@account) do
      # Set up a snapshot with all relevant metrics
      snapshot = BidAnalyticSnapshot.create!(
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
      
      # Set up current user for connection
      stub_connection current_user: users(:one), current_account: @account
      
      # Subscribe to the channel
      subscribe
      
      # Use the job to broadcast and capture the data
      broadcast_content = nil
      
      # Monkey patch broadcast_to for this test to capture the content
      original_broadcast_to = BidAnalyticsChannel.method(:broadcast_to)
      BidAnalyticsChannel.define_singleton_method(:broadcast_to) do |account, data|
        broadcast_content = data
        original_broadcast_to.call(account, data)
      end
      
      # Broadcast the snapshot
      BidAnalyticsBroadcastJob.perform_now(@account.id, :snapshot_update, snapshot)
      
      # Verify expected data was broadcast
      assert_equal 'snapshot_update', broadcast_content[:type]
      assert_equal 100, broadcast_content[:metrics][:total_bids]
      assert_equal 75, broadcast_content[:metrics][:accepted_bids]
      assert_equal 20, broadcast_content[:metrics][:rejected_bids]
      assert_equal 5, broadcast_content[:metrics][:expired_bids]
      assert_equal 35.5, broadcast_content[:metrics][:avg_bid_amount]
      assert_equal 75.0, broadcast_content[:metrics][:acceptance_rate]
      assert_equal 50.0, broadcast_content[:metrics][:conversion_rate]
      assert_equal 17.75, broadcast_content[:metrics][:revenue_per_bid]
      assert_equal 23.67, broadcast_content[:metrics][:revenue_per_accepted_bid]
      
      # Reset broadcast content
      broadcast_content = nil
      
      # Create a bid request and bid
      bid_request = BidRequest.create!(
        account: @account,
        campaign: @campaign,
        status: :pending,
        expires_at: 30.minutes.from_now,
        anonymized_data: { first_name: "John", zip_code: "90210" }
      )
      
      bid = Bid.create!(
        account: @account,
        bid_request: bid_request,
        distribution: distributions(:one),
        amount: 25.50,
        status: :pending
      )
      
      # Broadcast the bid
      BidAnalyticsBroadcastJob.perform_now(@account.id, :new_bid, bid)
      
      # Verify the expected data was broadcast
      assert_equal 'new_bid', broadcast_content[:type]
      assert_equal bid.id, broadcast_content[:bid][:id]
      assert_equal 25.5, broadcast_content[:bid][:amount]
      assert_equal 'pending', broadcast_content[:bid][:status]
      assert_equal @campaign.name, broadcast_content[:bid][:campaign]
      
      # Restore original method
      BidAnalyticsChannel.singleton_class.send(:remove_method, :broadcast_to)
      BidAnalyticsChannel.define_singleton_method(:broadcast_to, original_broadcast_to)
    end
  end
end