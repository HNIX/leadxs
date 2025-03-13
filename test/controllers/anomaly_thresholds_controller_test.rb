require "test_helper"

class AnomalyThresholdsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get anomaly_thresholds_index_url
    assert_response :success
  end

  test "should get show" do
    get anomaly_thresholds_show_url
    assert_response :success
  end

  test "should get new" do
    get anomaly_thresholds_new_url
    assert_response :success
  end

  test "should get create" do
    get anomaly_thresholds_create_url
    assert_response :success
  end

  test "should get edit" do
    get anomaly_thresholds_edit_url
    assert_response :success
  end

  test "should get update" do
    get anomaly_thresholds_update_url
    assert_response :success
  end

  test "should get destroy" do
    get anomaly_thresholds_destroy_url
    assert_response :success
  end
end
