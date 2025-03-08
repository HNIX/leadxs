require "test_helper"

class SourceTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @campaign = campaigns(:one)
    @company = companies(:one)
    
    # Set current tenant for testing
    ActsAsTenant.current_tenant = @account
  end
  
  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "should create a valid source" do
    source = Source.new(
      name: "Test Source",
      integration_type: "affiliate",
      status: "active",
      campaign: @campaign,
      company: @company
    )
    
    assert source.valid?
    assert source.save
    assert_not_nil source.token
  end
  
  test "should require a name" do
    source = Source.new(
      integration_type: "affiliate",
      status: "active",
      campaign: @campaign,
      company: @company
    )
    
    assert_not source.valid?
    assert_includes source.errors[:name], "can't be blank"
  end
  
  test "should have unique name per account" do
    source1 = Source.create!(
      name: "Unique Source",
      integration_type: "affiliate",
      status: "active",
      campaign: @campaign,
      company: @company
    )
    
    source2 = Source.new(
      name: "Unique Source",
      integration_type: "affiliate",
      status: "active",
      campaign: @campaign,
      company: @company
    )
    
    assert_not source2.valid?
    assert_includes source2.errors[:name], "has already been taken"
  end
  
  test "should validate status" do
    source = Source.new(
      name: "Test Source",
      integration_type: "affiliate",
      status: "invalid_status",
      campaign: @campaign,
      company: @company
    )
    
    assert_not source.valid?
    assert_includes source.errors[:status], "is not included in the list"
  end
  
  test "should validate integration_type" do
    source = Source.new(
      name: "Test Source",
      integration_type: "invalid_type",
      status: "active",
      campaign: @campaign,
      company: @company
    )
    
    assert_not source.valid?
    assert_includes source.errors[:integration_type], "is not included in the list"
  end
  
  test "should generate token on creation" do
    source = Source.create!(
      name: "Token Source",
      integration_type: "affiliate",
      status: "active",
      campaign: @campaign,
      company: @company
    )
    
    assert_not_nil source.token
    assert_not_empty source.token
  end
  
  test "should regenerate token" do
    source = Source.create!(
      name: "Regenerate Token Source",
      integration_type: "affiliate",
      status: "active",
      campaign: @campaign,
      company: @company
    )
    
    original_token = source.token
    source.regenerate_token!
    
    assert_not_equal original_token, source.token
  end
  
  test "should calculate revenue correctly" do
    source = Source.new(
      name: "Revenue Source",
      integration_type: "affiliate",
      status: "active",
      payout: 10.50,
      campaign: @campaign,
      company: @company
    )
    
    assert_equal 10.50, source.calculate_revenue
    assert_equal 21.00, source.calculate_revenue(2)
  end
  
  test "should calculate profit correctly" do
    source = Source.new(
      name: "Profit Source",
      integration_type: "affiliate",
      status: "active",
      payout: 5.25,
      campaign: @campaign,
      company: @company
    )
    
    assert_equal 4.75, source.calculate_profit(10.00)
    assert_equal 9.50, source.calculate_profit(10.00, 2)
  end
end