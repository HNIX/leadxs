require "test_helper"

class LeadDistributionServiceTest < ActiveSupport::TestCase
  setup do
    # Load or create test data
    @account = Account.first || Account.create!(name: "Test Account")
    @campaign = Campaign.first || Campaign.create!(
      name: "Test Campaign",
      campaign_type: "ping_post",
      distribution_method: "highest_bid",
      account: @account,
      status: "active",
      vertical: Vertical.first || Vertical.create!(name: "Test Vertical", account: @account)
    )
    
    @distribution = Distribution.first || Distribution.create!(
      name: "Test Distribution",
      endpoint_url: "https://example.com/test",
      company: Company.first || Company.create!(name: "Test Company", account: @account),
      account: @account
    )
    
    @lead = Lead.first || Lead.create!(
      campaign: @campaign,
      account: @account,
      status: :new_lead,
      unique_id: SecureRandom.uuid
    )
    
    # Ensure we have a campaign distribution
    @campaign_distribution = CampaignDistribution.where(
      campaign: @campaign, 
      distribution: @distribution
    ).first_or_create(active: true)
    
    # Create a second distribution for testing multiple distributions
    @distribution2 = Distribution.where(name: "Test Distribution 2").first_or_create(
      endpoint_url: "https://example.com/test2",
      company: Company.first,
      account: @account
    )
    
    @campaign_distribution2 = CampaignDistribution.where(
      campaign: @campaign, 
      distribution: @distribution2
    ).first_or_create(active: true)
  end
  
  test "distributes lead to all active distributions" do
    # Create a lead
    lead = @lead
    
    # Create distribution service
    service = LeadDistributionService.new(lead)
    
    # Skip the test that requires HTTP stubbing
    skip "This test requires stubbing HTTP requests"
  end
  
  test "distributes lead to specific distribution" do
    # Create a lead
    lead = @lead
    
    # Get a campaign distribution
    campaign_distribution = @campaign_distribution
    
    # Create distribution service
    service = LeadDistributionService.new(lead)
    
    # Skip the test that requires HTTP stubbing
    skip "This test requires stubbing HTTP requests"
  end
  
  test "selects winner based on highest bid" do
    # Create a lead
    lead = @lead
    campaign = @campaign
    
    # Update campaign to use highest bid
    campaign.update(distribution_method: "highest_bid")
    
    # Create distribution service
    service = LeadDistributionService.new(lead)
    
    # Create test distribution data
    distribution1 = @distribution
    distribution2 = @distribution2
    
    distributions_data = [
      { distribution: distribution1, bid: 10.0, priority: 1 },
      { distribution: distribution2, bid: 20.0, priority: 2 }
    ]
    
    # Select winner
    winner = service.select_winner(distributions_data)
    
    # Highest bid should win
    assert_equal distribution2, winner[:distribution]
    assert_equal 20.0, winner[:bid]
  end
  
  test "selects winner based on priority for waterfall" do
    # Create a lead
    lead = @lead
    campaign = @campaign
    
    # Update campaign to use waterfall
    campaign.update(distribution_method: "waterfall")
    
    # Create distribution service
    service = LeadDistributionService.new(lead)
    
    # Create test distribution data
    distribution1 = @distribution
    distribution2 = @distribution2
    
    distributions_data = [
      { distribution: distribution1, bid: 20.0, priority: 2 },
      { distribution: distribution2, bid: 10.0, priority: 1 }
    ]
    
    # Select winner
    winner = service.select_winner(distributions_data)
    
    # Lowest priority should win
    assert_equal distribution2, winner[:distribution]
    assert_equal 1, winner[:priority]
  end
  
  test "handles weighted random selection" do
    # Create a lead
    lead = @lead
    campaign = @campaign
    
    # Update campaign to use weighted random
    campaign.update(distribution_method: "weighted_random")
    
    # Create distribution service
    service = LeadDistributionService.new(lead)
    
    # Create test distribution data with only one option (to make test deterministic)
    distribution1 = @distribution
    
    distributions_data = [
      { distribution: distribution1, bid: 10.0, priority: 1 }
    ]
    
    # Select winner multiple times (should always be the same with only one option)
    10.times do
      winner = service.select_winner(distributions_data)
      assert_equal distribution1, winner[:distribution]
    end
  end
  
  test "updates timestamp for round robin" do
    # Create a lead
    lead = @lead
    
    # Get a campaign distribution
    campaign_distribution = @campaign_distribution
    
    # Create distribution service
    service = LeadDistributionService.new(lead)
    
    # Skip the test that requires HTTP stubbing
    skip "This test requires stubbing HTTP requests"
  end
end