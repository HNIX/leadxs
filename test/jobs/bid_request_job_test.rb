require "test_helper"

class BidRequestJobTest < ActiveJob::TestCase
  setup do
    @account = accounts(:one)
    # Set current tenant for all tests
    ActsAsTenant.current_tenant = @account
    
    @campaign = campaigns(:one)
    @distribution = distributions(:one)
    
    # Create a bid request for testing
    @bid_request = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :active,
      expires_at: Time.current + 30.minutes,
      anonymized_data: { "first_name": "John", "zip_code": "90210" }
    )
    
    # Set up distribution details
    @distribution.update!(
      endpoint_url: "https://example.com/bids",
      bid_endpoint_url: "https://example.com/bids/new",
      bidding_enabled: true,
      bidding_timeout_seconds: 2,
      base_bid_amount: 10.0
    )
  end
  
  # Clean up tenant after tests
  teardown do
    ActsAsTenant.current_tenant = nil
  end
  
  test "should process bid request and create bid" do
    # Mock the HTTP request using Minitest stubbing
    expected_response = { bid_amount: 12.50 }.to_json

    # Create a mock HTTP response
    mock_response = Minitest::Mock.new
    mock_response.expect :code, '200'
    mock_response.expect :body, expected_response
    
    # Patch the HTTP request method to use our mock
    original_request_method = Net::HTTP.instance_method(:request)
    
    Net::HTTP.define_method(:request) do |*args|
      mock_response
    end
    
    begin
      # Execute the job
      assert_difference ["Bid.count", "ApiRequest.count"], 1 do
        BidRequestJob.perform_now(@bid_request.id, @distribution.id)
      end
      
      # Verify the bid was created with the right amount
      bid = Bid.last
      assert_equal @bid_request, bid.bid_request
      assert_equal @distribution, bid.distribution
      assert_equal 12.50, bid.amount
      assert_equal "pending", bid.status
      
      # Verify the API request was recorded - it's associated with the created bid, not distribution
      api_request = ApiRequest.last
      assert_equal "Bid", api_request.requestable_type
      assert_includes api_request.endpoint_url, "example.com/bids"
      assert_equal "post", api_request.request_method.to_s
    ensure
      # Restore the original method
      Net::HTTP.define_method(:request, original_request_method)
    end
  end
  
  test "should not create bid if bid request is expired" do
    # Update bid request to expired
    @bid_request.update!(status: :expired)
    
    # Execute the job
    assert_no_difference ["Bid.count", "ApiRequest.count"] do
      BidRequestJob.perform_now(@bid_request.id, @distribution.id)
    end
  end
  
  test "should not create bid if distribution is not found" do
    # Execute the job with non-existent distribution
    assert_no_difference ["Bid.count", "ApiRequest.count"] do
      BidRequestJob.perform_now(@bid_request.id, 999999)
    end
  end
  
  test "should not create bid if bid request is not found" do
    # Execute the job with non-existent bid request
    assert_no_difference ["Bid.count", "ApiRequest.count"] do
      BidRequestJob.perform_now(999999, @distribution.id)
    end
  end
  
  test "should handle api errors gracefully" do
    # Create a mock HTTP response with error
    mock_response = Minitest::Mock.new
    mock_response.expect :code, '500'
    mock_response.expect :body, "Internal Server Error"
    
    # Patch the HTTP request method
    original_request_method = Net::HTTP.instance_method(:request)
    
    Net::HTTP.define_method(:request) do |*args|
      mock_response
    end
    
    begin
      # Execute the job - should create API request but no bid
      assert_difference "ApiRequest.count", 1 do
        assert_no_difference "Bid.count" do
          BidRequestJob.perform_now(@bid_request.id, @distribution.id)
        end
      end
      
      # Verify the API request error was recorded
      api_request = ApiRequest.last
      assert_equal 500, api_request.response_code
      assert_equal "Internal Server Error", api_request.response_payload
    ensure
      # Restore the original method
      Net::HTTP.define_method(:request, original_request_method)
    end
  end
  
  test "should handle network errors gracefully" do
    # Mock a network error
    original_request_method = Net::HTTP.instance_method(:request)
    
    Net::HTTP.define_method(:request) do |*args|
      raise Timeout::Error.new("execution expired")
    end
    
    begin
      # Execute the job - should create API request but no bid
      assert_difference "ApiRequest.count", 1 do
        assert_no_difference "Bid.count" do
          BidRequestJob.perform_now(@bid_request.id, @distribution.id)
        end
      end
      
      # Verify the API request error was recorded
      api_request = ApiRequest.last
      assert_includes api_request.error.to_s, "execution expired"
    ensure
      # Restore the original method
      Net::HTTP.define_method(:request, original_request_method)
    end
  end
  
  test "should use bidding_timeout_seconds for request timeout" do
    # Set a custom timeout
    @distribution.update!(bidding_timeout_seconds: 5)
    
    # Create a flag to check if read_timeout is set correctly
    read_timeout_set_correctly = false
    
    # Create a mock response
    mock_response = Minitest::Mock.new
    mock_response.expect :code, '200'
    mock_response.expect :body, { bid_amount: 10.0 }.to_json
    
    # Save original methods
    original_new = Net::HTTP.method(:new)
    original_request_method = Net::HTTP.instance_method(:request)
    
    # Mock Net::HTTP.new to return our custom object
    Net::HTTP.define_singleton_method(:new) do |*args|
      http = original_new.call(*args)
      
      # Override read_timeout= to check if it's called with the right value
      original_timeout_setter = http.method(:read_timeout=)
      
      http.define_singleton_method(:read_timeout=) do |value|
        read_timeout_set_correctly = (value == 5)
        original_timeout_setter.call(value)
      end
      
      # Override request to return our mock response
      http.define_singleton_method(:request) do |*args|
        mock_response
      end
      
      http
    end
    
    begin
      # Execute the job
      BidRequestJob.perform_now(@bid_request.id, @distribution.id)
      
      # Assert that the timeout was set correctly
      assert read_timeout_set_correctly, "read_timeout was not set to 5"
    ensure
      # Restore original methods
      Net::HTTP.define_singleton_method(:new, original_new)
      Net::HTTP.define_method(:request, original_request_method)
    end
  end
  
  test "should extract bid amount from different response formats" do
    original_request_method = Net::HTTP.instance_method(:request)
    
    # Test JSON format with 'bid_amount' key
    # We need to use different bid requests for each test to prevent duplicates
    # Create additional bid requests
    bid_request2 = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :active,
      expires_at: Time.current + 30.minutes,
      anonymized_data: { "first_name": "Jane", "zip_code": "90210" }
    )
    
    bid_request3 = BidRequest.create!(
      account: @account,
      campaign: @campaign,
      status: :active,
      expires_at: Time.current + 30.minutes,
      anonymized_data: { "first_name": "Bob", "zip_code": "90210" }
    )
    
    # Test 1: bid_amount key
    mock_response1 = Minitest::Mock.new
    mock_response1.expect :code, '200'
    mock_response1.expect :body, { bid_amount: 15.50 }.to_json
    
    Net::HTTP.define_method(:request) do |*args|
      mock_response1
    end
    
    assert_difference "Bid.count", 1 do
      BidRequestJob.perform_now(@bid_request.id, @distribution.id)
    end
    assert_equal 15.50, Bid.last.amount
    
    # Reset the mock and test again
    # Test 2: amount key
    mock_response2 = Minitest::Mock.new
    mock_response2.expect :code, '200'
    mock_response2.expect :body, { amount: 16.75 }.to_json
    
    Net::HTTP.define_method(:request) do |*args|
      mock_response2
    end
    
    assert_difference "Bid.count", 1 do
      BidRequestJob.perform_now(bid_request2.id, @distribution.id)
    end
    assert_equal 16.75, Bid.last.amount
    
    # Reset the mock once more
    # Test 3: bid key
    mock_response3 = Minitest::Mock.new
    mock_response3.expect :code, '200'
    mock_response3.expect :body, { bid: 17.25 }.to_json
    
    Net::HTTP.define_method(:request) do |*args|
      mock_response3
    end
    
    assert_difference "Bid.count", 1 do
      BidRequestJob.perform_now(bid_request3.id, @distribution.id)
    end
    assert_equal 17.25, Bid.last.amount
    
    # Restore original method
    Net::HTTP.define_method(:request, original_request_method)
  end
  
  test "should not create bid with zero amount" do
    # Mock a response with zero bid
    mock_response = Minitest::Mock.new
    mock_response.expect :code, '200'
    mock_response.expect :body, { bid_amount: 0 }.to_json
    
    original_request_method = Net::HTTP.instance_method(:request)
    
    Net::HTTP.define_method(:request) do |*args|
      mock_response
    end
    
    begin
      # Execute the job - should create API request but no bid
      assert_difference "ApiRequest.count", 1 do
        assert_no_difference "Bid.count" do
          BidRequestJob.perform_now(@bid_request.id, @distribution.id)
        end
      end
    ensure
      # Restore original method
      Net::HTTP.define_method(:request, original_request_method)
    end
  end
end