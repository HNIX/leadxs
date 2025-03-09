require "test_helper"

class DistributionTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @company = companies(:one)
    
    # Set current tenant for testing
    ActsAsTenant.current_tenant = @account
    
    @distribution = Distribution.new(
      account: @account,
      name: "Test Distribution",
      company: @company,
      endpoint_url: "https://example.com/api/leads",
      request_method: :post,
      request_format: :json
    )
  end
  
  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "valid distribution" do
    assert @distribution.valid?
  end

  test "requires name" do
    @distribution.name = nil
    assert_not @distribution.valid?
    assert_includes @distribution.errors[:name], "can't be blank"
  end

  test "requires endpoint_url" do
    @distribution.endpoint_url = nil
    assert_not @distribution.valid?
    assert_includes @distribution.errors[:endpoint_url], "can't be blank"
  end

  test "requires request_method" do
    @distribution.request_method = nil
    assert_not @distribution.valid?
    assert_includes @distribution.errors[:request_method], "can't be blank"
  end

  test "requires request_format" do
    @distribution.request_format = nil
    assert_not @distribution.valid?
    assert_includes @distribution.errors[:request_format], "can't be blank"
  end

  test "has request_method enum" do
    @distribution.request_method = :get
    assert_equal "get", @distribution.request_method

    @distribution.request_method = :post
    assert_equal "post", @distribution.request_method

    @distribution.request_method = :put
    assert_equal "put", @distribution.request_method

    @distribution.request_method = :patch
    assert_equal "patch", @distribution.request_method
  end

  test "has request_format enum" do
    @distribution.request_format = :form
    assert_equal "form", @distribution.request_format

    @distribution.request_format = :json
    assert_equal "json", @distribution.request_format

    @distribution.request_format = :xml
    assert_equal "xml", @distribution.request_format
  end

  test "has status enum" do
    @distribution.status = :active
    assert_equal "active", @distribution.status
    assert @distribution.active?

    @distribution.status = :paused
    assert_equal "paused", @distribution.status
    assert_not @distribution.active?

    @distribution.status = :archived
    assert_equal "archived", @distribution.status
    assert_not @distribution.active?
  end

  test "has default status of active" do
    distribution = Distribution.new
    assert_equal "active", distribution.status
  end

  test "has default request_method of post" do
    distribution = Distribution.new
    assert_equal "post", distribution.request_method
  end

  test "has default request_format of json" do
    distribution = Distribution.new
    assert_equal "json", distribution.request_format
  end

  test "belongs to company" do
    assert_equal @company, @distribution.company
  end

  test "has many campaign_distributions dependent destroy" do
    assert_difference "CampaignDistribution.count", -1 do
      distributions(:one).destroy
    end
  end

  test "has many campaigns through campaign_distributions" do
    distribution = distributions(:one)
    campaign = campaigns(:one)
    
    # Verify the association is working correctly
    assert_includes distribution.campaigns, campaign
    
    # Test that we can access campaigns through the distribution
    assert_equal 1, distribution.campaigns.count
    assert_equal campaign.id, distribution.campaigns.first.id
  end

  test "has many headers dependent destroy" do
    distribution = distributions(:one)
    
    # Ensure we have headers for this distribution
    assert_equal 2, distribution.headers.count
    
    # Test that destroying the distribution destroys the headers
    assert_difference "Header.count", -2 do
      distribution.destroy
    end
  end
end
