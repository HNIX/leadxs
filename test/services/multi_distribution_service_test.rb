require "test_helper"

class MultiDistributionServiceTest < ActiveSupport::TestCase
  setup do
    # Setup test data
    @account = Account.first || Account.create!(name: "Test Account")
    @campaign = Campaign.first || Campaign.create!(
      name: "Test Campaign",
      campaign_type: "direct",
      distribution_method: "highest_bid",
      multi_distribution_strategy: "sequential", # Default to sequential
      max_distributions: 3,
      account: @account,
      status: "active",
      vertical: Vertical.first || Vertical.create!(name: "Test Vertical", account: @account)
    )
    
    @distribution1 = Distribution.where(name: "Test Distribution 1").first_or_create(
      endpoint_url: "https://example.com/test1",
      company: Company.first || Company.create!(name: "Test Company", account: @account),
      account: @account
    )
    
    @distribution2 = Distribution.where(name: "Test Distribution 2").first_or_create(
      endpoint_url: "https://example.com/test2",
      company: Company.first,
      account: @account
    )
    
    @distribution3 = Distribution.where(name: "Test Distribution 3").first_or_create(
      endpoint_url: "https://example.com/test3",
      company: Company.first,
      account: @account
    )
    
    @lead = Lead.first || Lead.create!(
      campaign: @campaign,
      account: @account,
      status: :new_lead,
      unique_id: SecureRandom.uuid
    )
    
    # Set up campaign distributions with different priorities
    @campaign_distribution1 = CampaignDistribution.where(
      campaign: @campaign, 
      distribution: @distribution1
    ).first_or_create(active: true, priority: 1)
    
    @campaign_distribution2 = CampaignDistribution.where(
      campaign: @campaign, 
      distribution: @distribution2
    ).first_or_create(active: true, priority: 2)
    
    @campaign_distribution3 = CampaignDistribution.where(
      campaign: @campaign, 
      distribution: @distribution3
    ).first_or_create(active: true, priority: 3)
  end
  
  # Helper to mock distribution results
  def mock_distribution_success(success)
    # Create a mock LeadDistributionService instance
    mock_service = Minitest::Mock.new
    
    # Set up the expected calls to distribute_to_specific!
    result = success ? 
      { success: true, distribution: @distribution1, message: "Success" } : 
      { success: false, distribution: @distribution1, error: "Test error" }
    
    # Expect the distribute_to_specific! call and return our mock result
    mock_service.expect :distribute_to_specific!, result, [Object]
    
    # Stub the LeadDistributionService new method to return our mock
    LeadDistributionService.stub :new, mock_service do
      yield
    end
    
    # Verify all expected calls were made
    mock_service.verify
  end
  
  test "single distribution strategy uses only the first distribution" do
    skip "This test requires better mocking support"
    # Set campaign to use single distribution strategy
    @campaign.update(multi_distribution_strategy: "single", max_distributions: 1)
    
    # Use our mock to test the service
    mock_distribution_success(true) do
      service = MultiDistributionService.new(@lead)
      result = service.distribute!
      
      assert result[:success]
      assert_equal 1, result[:success_count]
      assert_equal 0, result[:failure_count]
      assert_equal "single", result[:strategy]
    end
  end
  
  test "sequential strategy stops after first success" do
    skip "This test requires better mocking support"
    # Set campaign to use sequential distribution strategy
    @campaign.update(multi_distribution_strategy: "sequential", max_distributions: 3)
    
    # Use our mock to test the service
    mock_distribution_success(true) do
      service = MultiDistributionService.new(@lead)
      result = service.distribute!
      
      assert result[:success]
      assert_equal 1, result[:success_count]
      assert_equal 0, result[:failure_count]
      assert_equal "sequential", result[:strategy]
    end
  end
  
  test "parallel strategy tries all distributions" do
    skip "This test requires better mocking support"
    # Set campaign to use parallel distribution strategy
    @campaign.update(multi_distribution_strategy: "parallel", max_distributions: 3)
    
    # This test would need more sophisticated mocking to properly test
    # the parallel distribution behavior
  end
  
  test "respects max_distributions setting" do
    # Set limit to 2 distributions
    @campaign.update(max_distributions: 2)
    
    # Create a service with mocked internals to test the limit
    service = MultiDistributionService.new(@lead)
    
    # Get the active distributions directly to inspect the limit
    distributions = service.send(:active_distributions)
    limited = service.send(:limit_distributions, distributions)
    
    # Should have all 3 distributions before limiting
    assert_equal 3, distributions.count
    # Should be limited to 2 distributions after limiting
    assert_equal 2, limited.count
  end
  
  test "updates lead status based on results" do
    skip "This test requires better mocking of HTTP requests"
  end
  
  test "handles no active distributions" do
    # Deactivate all distributions
    CampaignDistribution.update_all(active: false)
    
    # Create the service and distribute
    service = MultiDistributionService.new(@lead)
    result = service.distribute!
    
    # Check the result
    assert_not result[:success]
    assert_equal "No active distributions found", result[:message]
    
    # Check that lead status was updated
    @lead.reload
    assert_equal "error", @lead.status
    assert_equal "No active distributions found", @lead.error_message
  end
end