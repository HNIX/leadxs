require "test_helper"

class DistributionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @company = companies(:one)
    @distribution = distributions(:one)
    
    sign_in @user
    
    # Use the account for multi-tenancy
    Current.account = @account
  end
  
  test "should get index" do
    get distributions_path
    assert_response :success
  end

  test "should get show" do
    get distribution_path(@distribution)
    assert_response :success
  end

  test "should get new" do
    get new_distribution_path
    assert_response :success
  end

  test "should get edit" do
    get edit_distribution_path(@distribution)
    assert_response :success
  end

  test "should create distribution" do
    assert_difference("Distribution.count") do
      post distributions_path, params: { 
        distribution: { 
          name: "New Distribution",
          company_id: @company.id,
          endpoint_url: "https://example.com/api/leads",
          request_method: "post",
          request_format: "json"
        }
      }
    end

    assert_redirected_to distribution_path(Distribution.last)
  end

  test "should update distribution" do
    patch distribution_path(@distribution), params: { 
      distribution: { 
        name: "Updated Distribution",
      }
    }
    
    assert_redirected_to distribution_path(@distribution)
    @distribution.reload
    assert_equal "Updated Distribution", @distribution.name
  end

  test "should destroy distribution" do
    assert_difference("Distribution.count", -1) do
      delete distribution_path(@distribution)
    end

    assert_redirected_to distributions_path
  end
end
