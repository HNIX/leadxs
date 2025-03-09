require "test_helper"

class CampaignDistributionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @campaign = campaigns(:one)
    @distribution = distributions(:one)
    @campaign_distribution = campaign_distributions(:one)
    
    sign_in @user
    
    # Use the account for multi-tenancy
    Current.account = @account
  end
  
  test "should get index" do
    get campaign_campaign_distributions_path(@campaign)
    assert_response :success
  end

  test "should get new" do
    get new_campaign_campaign_distribution_path(@campaign)
    assert_response :success
  end

  test "should create campaign_distribution" do
    # Use a different distribution for the test
    different_distribution = distributions(:two)
    
    assert_difference("CampaignDistribution.count") do
      post campaign_campaign_distributions_path(@campaign), params: { 
        campaign_distribution: { 
          distribution_id: different_distribution.id,
          active: true,
          priority: 5
        }
      }
    end

    assert_redirected_to campaign_campaign_distributions_path(@campaign)
  end

  test "should get show" do
    get campaign_distribution_path(@campaign_distribution)
    assert_response :success
  end

  test "should get edit" do
    get edit_campaign_distribution_path(@campaign_distribution)
    assert_response :success
  end

  test "should update campaign_distribution" do
    patch campaign_distribution_path(@campaign_distribution), params: { 
      campaign_distribution: { 
        priority: 10,
        active: false
      }
    }
    
    assert_redirected_to campaign_distribution_path(@campaign_distribution)
    @campaign_distribution.reload
    assert_equal 10, @campaign_distribution.priority
    assert_equal false, @campaign_distribution.active
  end

  test "should destroy campaign_distribution" do
    assert_difference("CampaignDistribution.count", -1) do
      delete campaign_distribution_path(@campaign_distribution)
    end

    assert_redirected_to campaign_campaign_distributions_path(@campaign_distribution.campaign)
  end
end
