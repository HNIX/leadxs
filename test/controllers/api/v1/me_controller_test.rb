require "test_helper"

class MeControllerTest < ActionDispatch::IntegrationTest
  test "returns current user details" do
    get api_v1_me_url, headers: {Authorization: "token #{user.api_tokens.first.token}"}
    assert_response :success

    assert_equal user.name, response.parsed_body["name"]
  end

  test "delete current user" do
    # Create a test user specifically for deletion
    test_user = User.create!(
      name: "Delete Test",
      email: "delete_test@example.com",
      password: "password",
      password_confirmation: "password",
      terms_of_service: true
    )
    
    # Create a token for the test user
    token = test_user.api_tokens.create!(name: "Test Token")
    
    # Delete the user via API
    assert_difference("User.count", -1) do
      delete api_v1_me_url, headers: {Authorization: "token #{token.token}"}
      assert_response :success
    end
  end

  def user
    @user ||= users(:one)
  end
end
