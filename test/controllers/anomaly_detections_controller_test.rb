require "test_helper"

class AnomalyDetectionsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get anomaly_detections_index_url
    assert_response :success
  end

  test "should get show" do
    get anomaly_detections_show_url
    assert_response :success
  end

  test "should get manage" do
    get anomaly_detections_manage_url
    assert_response :success
  end

  test "should get update" do
    get anomaly_detections_update_url
    assert_response :success
  end

  test "should get export" do
    get anomaly_detections_export_url
    assert_response :success
  end
end
