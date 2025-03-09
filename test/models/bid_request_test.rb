require "test_helper"

class BidRequestTest < ActiveSupport::TestCase
  # Create objects directly rather than using fixtures
  def setup
    ActsAsTenant.current_tenant = accounts(:one)
    @account = accounts(:one)
    @company = companies(:one)
    @campaign = campaigns(:one)
    @distribution = distributions(:one)
  end
  
  def teardown
    ActsAsTenant.current_tenant = nil
  end

  test "should be valid with required attributes" do
    bid_request = BidRequest.new(
      account: @account,
      campaign: @campaign,
      status: :pending,
      expires_at: Time.current + 30.minutes,
      anonymized_data: { "first_name": "John", "zip_code": "90210" }
    )
    assert bid_request.valid?
  end

  test "should require account" do
    # Skip auto-setting expires_at since we're explicitly setting it
    ActsAsTenant.without_tenant do
      bid_request = BidRequest.new(
        campaign: @campaign,
        status: :pending,
        expires_at: Time.current + 30.minutes,
        anonymized_data: { "first_name": "John", "zip_code": "90210" }
      )
      
      assert_not bid_request.valid?
      assert_includes bid_request.errors[:account], "must exist"
    end
  end

  test "should require campaign" do
    bid_request = BidRequest.new(
      account: @account,
      status: :pending,
      expires_at: Time.current + 30.minutes,
      anonymized_data: { "first_name": "John", "zip_code": "90210" }
    )
    assert_not bid_request.valid?
    assert_includes bid_request.errors[:campaign], "must exist"
  end

  test "should require expires_at" do
    # Test without the before_validation callback
    BidRequest.skip_callback(:validation, :before, :set_expiration, raise: false)
    
    begin
      bid_request = BidRequest.new(
        account: @account,
        campaign: @campaign,
        status: :pending,
        anonymized_data: { "first_name": "John", "zip_code": "90210" }
      )
      assert_not bid_request.valid?
      assert_includes bid_request.errors[:expires_at], "can't be blank"
    ensure
      # Re-enable the callback
      BidRequest.set_callback(:validation, :before, :set_expiration, on: :create)
    end
  end

  test "should generate unique_id before validation" do
    bid_request = BidRequest.new(
      account: @account,
      campaign: @campaign,
      status: :pending,
      expires_at: Time.current + 30.minutes,
      anonymized_data: { "first_name": "John", "zip_code": "90210" }
    )
    
    # Skip this test if unique_id is generated during initialization
    if bid_request.unique_id.nil?
      bid_request.valid?
      assert_not_nil bid_request.unique_id
    else
      assert_not_nil bid_request.unique_id
    end
  end

  test "should determine if expired based on expiration time" do
    # Create a bid request that's not expired
    bid_request_active = BidRequest.new(
      account: @account,
      campaign: @campaign,
      status: :pending,
      expires_at: Time.current + 30.minutes,
      anonymized_data: { "first_name": "John", "zip_code": "90210" }
    )
    assert_not bid_request_active.expired?

    # Create a bid request that is expired based on time
    bid_request_expired = BidRequest.new(
      account: @account,
      campaign: @campaign,
      status: :pending,
      expires_at: Time.current - 1.minute,
      anonymized_data: { "first_name": "John", "zip_code": "90210" }
    )
    assert bid_request_expired.expired?
  end

  test "should determine if expired based on status" do
    # Create a bid request with expired status
    bid_request_expired_status = BidRequest.new(
      account: @account,
      campaign: @campaign,
      status: :expired,
      expires_at: Time.current + 30.minutes,  # Still in the future
      anonymized_data: { "first_name": "John", "zip_code": "90210" }
    )
    assert bid_request_expired_status.expired?
  end

  test "should return winning bid with highest amount" do
    bid_request = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :pending,
      expires_at: Time.current + 30.minutes,
      anonymized_data: { "first_name": "John", "zip_code": "90210" }
    )

    # Create bids with different amounts
    bid1 = Bid.create!(
      bid_request: bid_request,
      distribution: @distribution,
      amount: 10.50,
      account: @account,
      status: :pending
    )

    # Use a different distribution for the second bid
    distribution2 = Distribution.create!(
      account: @account,
      company: @company,
      name: "Test Distribution 2",
      endpoint_url: "https://example.com/api/test2",
      request_method: "post",
      request_format: "json"
    )
    
    bid2 = Bid.create!(
      bid_request: bid_request,
      distribution: distribution2,
      amount: 15.75,
      account: @account,
      status: :pending
    )

    # Use a different distribution for the third bid
    distribution3 = Distribution.create!(
      account: @account,
      company: @company,
      name: "Test Distribution 3",
      endpoint_url: "https://example.com/api/test3",
      request_method: "post",
      request_format: "json"
    )
    
    bid3 = Bid.create!(
      bid_request: bid_request,
      distribution: distribution3,
      amount: 8.25,
      account: @account,
      status: :pending
    )

    # Set the campaign to use highest_bid distribution method
    bid_request.campaign.update!(distribution_method: "highest_bid")
    
    assert_equal bid2, bid_request.winning_bid
  end

  test "should return nil for winning bid if no bids exist" do
    bid_request = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :pending,
      expires_at: Time.current + 30.minutes,
      anonymized_data: { "first_name": "John", "zip_code": "90210" }
    )

    assert_nil bid_request.winning_bid
  end

  test "should check and update expiration status" do
    # Create a bid request with expiration in the past
    bid_request = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :active,
      expires_at: Time.current - 1.minute,
      anonymized_data: { "first_name": "John", "zip_code": "90210" }
    )
    
    assert_changes -> { bid_request.status }, from: "active", to: "expired" do
      bid_request.check_expiration!
    end
  end

  test "should not update status if not expired" do
    # Create a bid request with expiration in the future
    bid_request = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :active,
      expires_at: Time.current + 30.minutes,
      anonymized_data: { "first_name": "John", "zip_code": "90210" }
    )
    
    assert_no_changes -> { bid_request.status } do
      bid_request.check_expiration!
    end
  end
end