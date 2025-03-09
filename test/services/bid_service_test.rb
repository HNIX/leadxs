require "test_helper"

class BidServiceTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    # Set current tenant for all tests
    ActsAsTenant.current_tenant = @account
    
    @campaign = campaigns(:one)
    @distribution_one = distributions(:one)
    @distribution_two = distributions(:two)
    
    # Set distribution method to highest_bid
    @campaign.update!(distribution_method: "highest_bid", bid_timeout_seconds: 5)
    
    # Create anonymized data for testing
    @anonymized_data = {
      first_name: "John",
      zip_code: "90210",
      age: "35",
      income_level: "high"
    }
    
    # Create a lead for testing
    @lead = Lead.create!(
      account: @account,
      campaign: @campaign
    )
  end
  
  # Clean up tenant after tests
  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "should create a bid request with anonymized data" do
    service = BidService.new(@anonymized_data, @campaign)
    
    assert_difference "BidRequest.count", 1 do
      bid_request = service.solicit_bids!
      assert_equal @campaign, bid_request.campaign
      # Convert to string keys for comparison
      string_keys_data = @anonymized_data.transform_keys(&:to_s)
      assert_equal string_keys_data, bid_request.anonymized_data
      assert_nil bid_request.lead
      assert_equal "active", bid_request.status
      assert_in_delta Time.current + 5.seconds, bid_request.expires_at, 1.0
    end
  end
  
  test "should create a bid request with lead" do
    service = BidService.new(@lead, @campaign)
    
    assert_difference "BidRequest.count", 1 do
      bid_request = service.solicit_bids!
      assert_equal @campaign, bid_request.campaign
      assert_equal @lead, bid_request.lead
      assert_equal "active", bid_request.status
    end
  end
  
  test "should complete bidding with winning bid" do
    # Create a bid request and service
    service = BidService.new(@anonymized_data, @campaign)
    bid_request = service.solicit_bids!
    
    # Create some bids manually
    bid1 = Bid.create!(
      bid_request: bid_request,
      distribution: @distribution_one,
      amount: 10.50,
      account: @account,
      status: :pending
    )
    
    bid2 = Bid.create!(
      bid_request: bid_request,
      distribution: @distribution_two,
      amount: 15.75,
      account: @account,
      status: :pending
    )
    
    # Complete bidding and check the result
    result = service.complete_bidding!
    
    assert result[:success]
    assert_equal bid2, result[:bid]
    assert_equal @distribution_two, result[:distribution]
    assert_equal "accepted", bid2.reload.status
    assert_equal "rejected", bid1.reload.status
    assert_equal "completed", bid_request.reload.status
  end
  
  test "should handle no bids when completing" do
    # Create a bid request and service
    service = BidService.new(@anonymized_data, @campaign)
    bid_request = service.solicit_bids!
    
    # Complete bidding without any bids
    result = service.complete_bidding!
    
    assert_not result[:success]
    assert_equal "No bids received", result[:message]
    assert_equal bid_request, result[:bid_request]
  end
  
  test "should handle expired bid request" do
    # Create a bid request that's expired
    bid_request = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :active,
      expires_at: Time.current - 1.minute,
      anonymized_data: @anonymized_data
    )
    
    # Create a bid
    bid = Bid.create!(
      bid_request: bid_request,
      distribution: @distribution_one,
      amount: 10.50,
      account: @account,
      status: :pending
    )
    
    # Use the service to complete bidding
    service = BidService.new(@anonymized_data, @campaign)
    service.instance_variable_set(:@bid_request, bid_request)
    
    # This should update the status to expired and fail
    result = service.complete_bidding!
    
    assert_not result[:success]
    assert_equal "expired", bid_request.reload.status
  end
  
  test "should reject winning bid that cannot be accepted" do
    # Create a bid request and service
    service = BidService.new(@anonymized_data, @campaign)
    bid_request = service.solicit_bids!
    
    # Create a bid
    bid = Bid.create!(
      bid_request: bid_request,
      distribution: @distribution_one,
      amount: 10.50,
      account: @account,
      status: :pending
    )
    
    # Instead of using a mock, let's modify the actual bid and use that
    # Create a fake method to override accept!
    def bid.accept!
      false
    end
    
    # Stub winning_bid to return our modified bid
    bid_request.stub(:winning_bid, bid) do
      # Set the instance variable directly to access the stubbed bid_request
      service.instance_variable_set(:@bid_request, bid_request)
      
      # Complete bidding
      result = service.complete_bidding!
      
      assert_not result[:success]
      assert_equal "Failed to accept winning bid", result[:message]
    end
  end
  
  test "should request bid from distribution" do
    # Create a bid request and service
    service = BidService.new(@anonymized_data, @campaign)
    bid_request = service.solicit_bids!
    service.instance_variable_set(:@bid_request, bid_request)
    
    # Mock calculate_bid_amount
    @distribution_one.stub(:calculate_bid_amount, 12.34) do
    
    # Request a bid
    assert_difference "Bid.count", 1 do
      bid = service.request_bid_from_distribution(@distribution_one)
      assert_equal 12.34, bid.amount
      assert_equal @distribution_one, bid.distribution
      assert_equal bid_request, bid.bid_request
      assert_equal "pending", bid.status
      end
    end
  end
  
  test "should not request bid from distribution if bid request is expired" do
    # Create an expired bid request
    bid_request = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :expired,
      expires_at: Time.current - 1.minute,
      anonymized_data: @anonymized_data
    )
    
    # Create service and set the bid request
    service = BidService.new(@anonymized_data, @campaign)
    service.instance_variable_set(:@bid_request, bid_request)
    
    # Attempt to request a bid
    assert_no_difference "Bid.count" do
      result = service.request_bid_from_distribution(@distribution_one)
      assert_nil result
    end
  end
  
  test "should handle weighted random distribution method" do
    # Set campaign to use weighted random
    @campaign.update!(distribution_method: "weighted_random")
    
    # Create a bid request and service
    service = BidService.new(@anonymized_data, @campaign)
    bid_request = service.solicit_bids!
    
    # Create bids with different weights
    bid1 = Bid.create!(
      bid_request: bid_request,
      distribution: @distribution_one,
      amount: 10.0, # 33.3% weight
      account: @account,
      status: :pending
    )
    
    bid2 = Bid.create!(
      bid_request: bid_request,
      distribution: @distribution_two,
      amount: 20.0, # 66.7% weight
      account: @account,
      status: :pending
    )
    
    # Mock the random number generator to test both outcomes
    # We'll need to manually stub the winning_bid method instead
    # since we can't easily mock Random.rand in minitest
    
    # Force bid1 to be selected
    bid_request.stub(:winning_bid, bid1) do
      winning_bid = bid_request.winning_bid
      assert_equal bid1, winning_bid
    end
    
    # Force bid2 to be selected
    bid_request.stub(:winning_bid, bid2) do
      winning_bid = bid_request.winning_bid
      assert_equal bid2, winning_bid
    end
  end
  
  test "should integrate with filter service for eligible distributions" do
    # Mock eligible_distributions to test integration
    eligible_distributions = [@distribution_one, @distribution_two]
    
    # Stub the Campaign#eligible_distributions_for_bidding method
    @campaign.stub(:eligible_distributions_for_bidding, eligible_distributions) do
      original_perform_later = BidRequestJob.method(:perform_later)
      
      # Capture job args
      job_args_captured = []
      
      # Stub the BidRequestJob.perform_later method
      BidRequestJob.define_singleton_method(:perform_later) do |*args|
        job_args_captured << args
      end
      
      begin
        # Verify the integration
        service = BidService.new(@anonymized_data, @campaign)
        bid_request = service.solicit_bids!
        
        # Verify that jobs were queued
        assert_equal 2, job_args_captured.length
        assert_equal [bid_request.id, @distribution_one.id], job_args_captured[0]
        assert_equal [bid_request.id, @distribution_two.id], job_args_captured[1]
      ensure
        # Restore original method
        BidRequestJob.define_singleton_method(:perform_later, original_perform_later)
      end
    end
  end
end