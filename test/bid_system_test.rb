require "test_helper"

class BidSystemTest < ActiveSupport::TestCase
  # This is a simplified test for the bid system
  
  test "bid models can be created" do
    ActsAsTenant.current_tenant = accounts(:one)
    @account = accounts(:one)
    @campaign = campaigns(:one)
    
    # Create a bid request
    bid_request = BidRequest.new(
      account: @account,
      campaign: @campaign,
      status: :pending,
      expires_at: Time.current + 30.minutes,
      anonymized_data: { "first_name": "John", "zip_code": "90210" }
    )
    
    # Validate it
    assert bid_request.valid?
    
    # Check some key attributes
    assert_equal "pending", bid_request.status
    assert bid_request.expires_at > Time.current
    
    # Clean up
    ActsAsTenant.current_tenant = nil
  end
end