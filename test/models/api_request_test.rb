require "test_helper"

class ApiRequestTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @distribution = distributions(:one)
    
    # Set current tenant for testing
    ActsAsTenant.current_tenant = @account
    
    @api_request = ApiRequest.new(
      account: @account,
      requestable: @distribution,
      endpoint_url: "https://example.com/api/leads",
      request_method: :post,
      request_payload: '{"name":"John Doe","email":"john@example.com"}',
      response_code: 200,
      response_payload: '{"success":true,"id":"123"}',
      duration_ms: 350
    )
  end
  
  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "valid api request" do
    assert @api_request.valid?
  end

  test "requires requestable" do
    @api_request.requestable = nil
    assert_not @api_request.valid?
  end

  test "requires endpoint_url" do
    @api_request.endpoint_url = nil
    assert_not @api_request.valid?
    assert_includes @api_request.errors[:endpoint_url], "can't be blank"
  end

  test "requires request_method" do
    @api_request.request_method = nil
    assert_not @api_request.valid?
    assert_includes @api_request.errors[:request_method], "can't be blank"
  end

  test "lead association is optional" do
    @api_request.lead_id = nil
    assert @api_request.valid?
  end

  test "has request_method enum" do
    @api_request.request_method = :get
    assert_equal "get", @api_request.request_method

    @api_request.request_method = :post
    assert_equal "post", @api_request.request_method

    @api_request.request_method = :put
    assert_equal "put", @api_request.request_method

    @api_request.request_method = :patch
    assert_equal "patch", @api_request.request_method
  end

  test "successful? returns true for successful requests" do
    @api_request.response_code = 200
    @api_request.error = nil
    assert @api_request.successful?

    @api_request.response_code = 201
    assert @api_request.successful?

    @api_request.response_code = 299
    assert @api_request.successful?
  end

  test "successful? returns false for failed requests" do
    @api_request.response_code = 404
    assert_not @api_request.successful?

    @api_request.response_code = 500
    assert_not @api_request.successful?

    @api_request.response_code = 200
    @api_request.error = "Connection timed out"
    assert_not @api_request.successful?

    @api_request.response_code = nil
    @api_request.error = nil
    assert_not @api_request.successful?
  end

  test "failed? returns the opposite of successful?" do
    @api_request.response_code = 200
    @api_request.error = nil
    assert_not @api_request.failed?

    @api_request.response_code = 500
    assert @api_request.failed?
  end

  test "mark_as_sent sets the sent_at timestamp" do
    assert_nil @api_request.sent_at
    @api_request.mark_as_sent
    assert_not_nil @api_request.sent_at
  end

  test "successful scope returns only successful requests" do
    successful = api_requests(:successful)
    failed = api_requests(:failed)

    requests = ApiRequest.successful
    assert_includes requests, successful
    assert_not_includes requests, failed
  end

  test "failed scope returns only failed requests" do
    successful = api_requests(:successful)
    failed = api_requests(:failed)

    requests = ApiRequest.failed
    assert_includes requests, failed
    assert_not_includes requests, successful
  end
end
