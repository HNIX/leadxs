require "test_helper"

class ComplianceControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get compliance_show_url
    assert_response :success
  end

  test "should get history" do
    get compliance_history_url
    assert_response :success
  end

  test "should get report" do
    get compliance_report_url
    assert_response :success
  end

  test "should get consent" do
    get compliance_consent_url
    assert_response :success
  end

  test "should get export" do
    get compliance_export_url
    assert_response :success
  end
end
