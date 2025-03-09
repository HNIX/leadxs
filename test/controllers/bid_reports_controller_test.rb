require "test_helper"

class BidReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @user = users(:one)
    @bid_analytic_snapshot = bid_analytic_snapshots(:one)
    
    # Set up multi-tenancy for tests
    ActsAsTenant.current_tenant = @account
    
    # Log in the user
    sign_in @user
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "should get index" do
    get bid_reports_url
    assert_response :success
  end

  test "should get show" do
    get bid_report_url(@bid_analytic_snapshot)
    assert_response :success
  end
  
  test "should get campaign report" do
    get campaign_bid_report_url(@bid_analytic_snapshot.campaign)
    assert_response :success
  end
  
  test "should get distribution report" do
    # Skip if no distribution is associated with the snapshot
    skip unless @bid_analytic_snapshot.distribution.present?
    
    get distribution_bid_report_url(@bid_analytic_snapshot.distribution)
    assert_response :success
  end
end
