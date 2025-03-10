class BidService
  def initialize(lead_or_anonymized_data, campaign)
    @campaign = campaign
    
    if lead_or_anonymized_data.is_a?(Lead)
      @lead = lead_or_anonymized_data
      # Generate anonymized data with our robust implementation
      @anonymized_data = @lead.anonymized_data
      @bid_metadata = {
        lead_id: @lead.unique_id,
        campaign_id: @campaign.id,
        created_at: Time.current.iso8601,
        source_type: @lead.source&.integration_type
      }
    else
      @lead = nil
      @anonymized_data = lead_or_anonymized_data
      @bid_metadata = {
        campaign_id: @campaign.id,
        created_at: Time.current.iso8601
      }
    end
    
    @bid_request = nil
  end
  
  # Create a bid request and solicit bids from eligible distributions
  def solicit_bids!
    # Determine the account to use
    account = ActsAsTenant.current_tenant || @lead&.account || @campaign.account
    
    # Create a new bid request with enriched anonymized data
    @bid_request = BidRequest.create!(
      account: account,
      campaign: @campaign,
      lead: @lead,
      anonymized_data: @anonymized_data,
      bid_metadata: @bid_metadata,
      status: :active,
      expires_at: Time.current + @campaign.bid_timeout_seconds.seconds
    )
    
    # Find eligible distributions
    eligible_distributions = @campaign.eligible_distributions_for_bidding(@anonymized_data)
    
    # Request bids asynchronously from each distribution
    eligible_distributions.each do |distribution|
      BidRequestJob.perform_later(@bid_request.id, distribution.id)
    end
    
    # Schedule job to process the bid request after it expires
    ProcessBidRequestJob.set(wait_until: @bid_request.expires_at + 2.seconds).perform_later(@bid_request.id)
    
    @bid_request
  end
  
  # Complete the bidding process and select a winner
  def complete_bidding!
    return { success: false, message: "No bid request found" } unless @bid_request
    
    # Make sure the bid request has all possible bids
    # In practice, you might want to wait for a timeout or minimum number of bids
    
    # Check for expiration
    @bid_request.check_expiration!
    
    # Use the LeadDistributionService to select a winner according to campaign distribution method
    winning_bid = select_winning_bid
    
    if winning_bid.nil?
      return {
        success: false,
        message: "No bids received or no winner could be selected",
        bid_request: @bid_request
      }
    end
    
    # Accept the winning bid
    if winning_bid.accept!
      {
        success: true,
        bid: winning_bid,
        distribution: winning_bid.distribution,
        bid_request: @bid_request
      }
    else
      {
        success: false,
        message: "Failed to accept winning bid",
        bid_request: @bid_request
      }
    end
  end
  
  private
  
  # Use LeadDistributionService to select the winning bid according to campaign's distribution method
  def select_winning_bid
    return nil if @bid_request.bids.empty?
    
    # Create a distribution service (if we have a lead)
    distribution_service = @lead ? LeadDistributionService.new(@lead) : nil
    
    # If we don't have a lead or a distribution service, fall back to the basic selection
    return @bid_request.winning_bid unless distribution_service
    
    # Format bid data for the distribution service
    distributions_data = @bid_request.bids.map do |bid|
      campaign_distribution = @campaign.campaign_distributions.find_by(distribution: bid.distribution)
      
      {
        bid: bid.amount,
        distribution: bid.distribution,
        campaign_distribution: campaign_distribution,
        priority: campaign_distribution&.priority || 999
      }
    end
    
    # Use the distribution service to select a winner
    winning_data = distribution_service.select_winner(distributions_data)
    return nil unless winning_data
    
    # Find and return the corresponding bid
    @bid_request.bids.find_by(distribution: winning_data[:distribution])
  end
  
  # Request a single bid from a distribution
  def request_bid_from_distribution(distribution)
    return nil unless @bid_request
    return nil if @bid_request.expired?
    
    # Calculate bid amount based on lead data
    bid_amount = distribution.calculate_bid_amount(@anonymized_data)
    
    # Create a bid
    Bid.create!(
      bid_request: @bid_request,
      distribution: distribution,
      amount: bid_amount,
      account: @bid_request.account,
      status: :pending
    )
  end
end