require "test_helper"

class BidTest < ActiveSupport::TestCase
  def setup
    ActsAsTenant.current_tenant = accounts(:one)
    @account = accounts(:one)
    @campaign = campaigns(:one)
    @distribution = distributions(:one)
    @bid_request = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :active,
      expires_at: Time.current + 30.minutes,
      anonymized_data: { "first_name": "John", "zip_code": "90210" }
    )
  end
  
  def teardown
    ActsAsTenant.current_tenant = nil
  end

  test "should be valid with required attributes" do
    bid = Bid.new(
      bid_request: @bid_request,
      distribution: @distribution,
      amount: 10.50,
      account: @account,
      status: :pending
    )
    assert bid.valid?
  end

  test "should require bid_request" do
    bid = Bid.new(
      distribution: @distribution,
      amount: 10.50,
      account: @account,
      status: :pending
    )
    assert_not bid.valid?
    assert_includes bid.errors[:bid_request], "must exist"
  end

  test "should require distribution" do
    bid = Bid.new(
      bid_request: @bid_request,
      amount: 10.50,
      account: @account,
      status: :pending
    )
    assert_not bid.valid?
    assert_includes bid.errors[:distribution], "must exist"
  end

  test "should require amount" do
    bid = Bid.new(
      bid_request: @bid_request,
      distribution: @distribution,
      account: @account,
      status: :pending
    )
    assert_not bid.valid?
    assert_includes bid.errors[:amount], "can't be blank"
  end

  test "should require amount to be greater than or equal to zero" do
    bid = Bid.new(
      bid_request: @bid_request,
      distribution: @distribution,
      amount: -1.0,
      account: @account,
      status: :pending
    )
    assert_not bid.valid?
    assert_includes bid.errors[:amount], "must be greater than or equal to 0"
  end

  test "should enforce uniqueness of distribution per bid request" do
    # Create an initial bid
    Bid.create!(
      bid_request: @bid_request,
      distribution: @distribution,
      amount: 10.50,
      account: @account,
      status: :pending
    )
    
    # Try to create another bid with the same distribution
    duplicate_bid = Bid.new(
      bid_request: @bid_request,
      distribution: @distribution,
      amount: 12.75,
      account: @account,
      status: :pending
    )
    
    assert_not duplicate_bid.valid?
    assert_includes duplicate_bid.errors[:distribution_id], "has already placed a bid"
  end

  test "should determine if bid is the winning bid" do
    # Create multiple bids
    bid1 = Bid.create!(
      bid_request: @bid_request,
      distribution: @distribution,
      amount: 10.50,
      account: @account,
      status: :pending
    )
    
    # Create a higher bid
    bid2 = Bid.create!(
      bid_request: @bid_request,
      distribution: distributions(:two),
      amount: 15.75,
      account: @account,
      status: :pending
    )
    
    # Set up the campaign to use highest_bid method
    @bid_request.campaign.update!(distribution_method: "highest_bid")
    
    # Check which bid is winning
    assert_not bid1.winning_bid?
    assert bid2.winning_bid?
  end

  test "should accept a bid and reject others" do
    # Create multiple bids
    bid1 = Bid.create!(
      bid_request: @bid_request,
      distribution: @distribution,
      amount: 10.50,
      account: @account,
      status: :pending
    )
    
    bid2 = Bid.create!(
      bid_request: @bid_request,
      distribution: distributions(:two),
      amount: 15.75,
      account: @account,
      status: :pending
    )
    
    # Accept the first bid
    assert_changes -> { [bid1.reload.status, @bid_request.reload.status] }, 
                  from: ["pending", "active"], 
                  to: ["accepted", "completed"] do
      bid1.accept!
    end
    
    # Verify the other bid was rejected
    assert_equal "rejected", bid2.reload.status
  end

  test "should not accept a bid for an expired request" do
    # Create an expired bid request
    expired_request = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :expired,
      expires_at: Time.current - 10.minutes,
      anonymized_data: { "first_name": "John", "zip_code": "90210" }
    )
    
    # Create a bid for the expired request
    bid = Bid.create!(
      bid_request: expired_request,
      distribution: @distribution,
      amount: 10.50,
      account: @account,
      status: :pending
    )
    
    # Try to accept the bid
    assert_no_changes -> { [bid.reload.status, expired_request.reload.status] } do
      result = bid.accept!
      assert_equal false, result
    end
  end

  test "should mark bid as expired" do
    bid = Bid.create!(
      bid_request: @bid_request,
      distribution: @distribution,
      amount: 10.50,
      account: @account,
      status: :pending
    )
    
    assert_changes -> { bid.reload.status }, from: "pending", to: "expired" do
      bid.expire!
    end
  end

  test "should not expire accepted bids" do
    bid = Bid.create!(
      bid_request: @bid_request,
      distribution: @distribution,
      amount: 10.50,
      account: @account,
      status: :pending
    )
    
    # Accept the bid
    bid.accept!
    
    # Try to expire it
    assert_no_changes -> { bid.reload.status } do
      bid.expire!
    end
  end
end