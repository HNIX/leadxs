require "test_helper"

class DistributionTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @company = companies(:one)
    @distribution = Distribution.new(
      name: "Test Distribution",
      company: @company,
      endpoint_url: "https://example.com/api/leads",
      request_method: :post,
      request_format: :json
    )
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
    @distribution.save
    campaign = campaigns(:one)
    
    campaign_distribution = CampaignDistribution.create!(
      campaign: campaign,
      distribution: @distribution
    )
    
    assert_includes @distribution.campaign_distributions, campaign_distribution
    assert_difference -> { CampaignDistribution.count }, -1 do
      @distribution.destroy
    end
  end

  test "has many campaigns through campaign_distributions" do
    @distribution.save
    campaign = campaigns(:one)
    
    CampaignDistribution.create!(
      campaign: campaign,
      distribution: @distribution
    )
    
    assert_includes @distribution.campaigns, campaign
  end

  test "has many headers dependent destroy" do
    @distribution.save
    header = Header.create!(
      distribution: @distribution,
      name: "Authorization",
      value: "Bearer token123"
    )
    
    assert_includes @distribution.headers, header
    assert_difference -> { Header.count }, -1 do
      @distribution.destroy
    end
  end
end
