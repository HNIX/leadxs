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
      # Initialize lead activity service when we have a lead
      @lead_activity_service = LeadActivityService.new
    else
      @lead = nil
      @anonymized_data = lead_or_anonymized_data
      @bid_metadata = {
        campaign_id: @campaign.id,
        created_at: Time.current.iso8601
      }
      @lead_activity_service = nil
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
    
    # Find all eligible distributions regardless of type
    all_eligible_distributions = @campaign.eligible_distributions(@anonymized_data)
    Rails.logger.info("BidService found #{all_eligible_distributions.count} total eligible distributions")
    
    # Filter to get only those that support bidding (ping_post, ping_only, or post_only with bidding enabled)
    eligible_distributions = all_eligible_distributions.select do |dist|
      # Include distributions explicitly set up for ping/post operations
      dist.endpoint_type.in?(["ping_post", "ping_only"]) ||
      # Include post_only distributions that have bidding enabled
      (dist.endpoint_type == "post_only" && dist.bidding_enabled?)
    end
    
    Rails.logger.info("BidService found #{eligible_distributions.count} eligible distributions for bidding")
    
    if eligible_distributions.empty?
      Rails.logger.warn("BidService: No eligible distributions found for campaign #{@campaign.id}")
    else
      # Log the distributions for debugging
      eligible_distributions.each do |dist|
        Rails.logger.info("BidService eligible distribution: #{dist.id} - #{dist.name} - endpoint: #{dist.bid_endpoint_url || dist.endpoint_url}")
      end
    end
    
    # Request bids asynchronously from each distribution
    eligible_distributions.each do |distribution|
      Rails.logger.info("BidService queuing BidRequestJob for request #{@bid_request.id} to distribution #{distribution.id}")
      BidRequestJob.perform_later(@bid_request.id, distribution.id)
    end
    
    # Schedule jobs to process the bid request:
    # 1. At expiration time (+2 seconds for buffer)
    # 2. With a safety fallback at extended expiration time (+15 seconds)
    # This ensures we handle the request even if the first job fails or is delayed
    
    # Primary job scheduled just after expiration
    ProcessBidRequestJob.set(
      wait_until: @bid_request.expires_at + 2.seconds
    ).perform_later(@bid_request.id)
    
    # Safety fallback job with a bigger buffer - will be a no-op if already completed
    ProcessBidRequestJob.set(
      wait_until: @bid_request.expires_at + 15.seconds,
      queue: :fallback_processing
    ).perform_later(@bid_request.id)
    
    @bid_request
  end
  
  # Complete the bidding process and select a winner
  def complete_bidding!
    return { success: false, message: "No bid request found" } unless @bid_request
    
    # Make sure the bid request has all possible bids
    # Check for expiration
    @bid_request.check_expiration!
    
    # Get all valid bids
    valid_bids = @bid_request.bids.where(status: :pending)
    
    # If no valid bids, return early
    if valid_bids.empty?
      return {
        success: false,
        message: "No bids received",
        bid_request: @bid_request
      }
    end
    
    # Use the distribution service to select a winner according to campaign distribution method
    winning_bid = select_winning_bid
    
    if winning_bid.nil?
      return {
        success: false,
        message: "No winner could be selected from #{valid_bids.count} bids",
        bid_request: @bid_request
      }
    end
    
    # Accept the winning bid
    if winning_bid.accept!
      # Record winning bid selected activity if we have a lead
      if @lead && @lead_activity_service
        @lead_activity_service.record_bid_selected(@lead, winning_bid, {
          selection_method: @campaign.distribution_method,
          total_bids: @bid_request.bids.count,
          bid_request_id: @bid_request.id,
          winning_amount: winning_bid.amount
        })
      end
      
      # If we have a lead, proceed with distribution
      if @lead
        # Mark the bid request as completed
        @bid_request.update(status: :completed, completed_at: Time.current)
        
        # Post the full lead data to the winning distribution
        distribute_result = distribute_to_winning_bidder(winning_bid)
        
        return {
          success: distribute_result[:success],
          bid: winning_bid,
          distribution: winning_bid.distribution,
          bid_request: @bid_request,
          distribution_result: distribute_result
        }
      else
        # For anonymous data scenarios, just return the winning bid
        {
          success: true,
          bid: winning_bid,
          distribution: winning_bid.distribution,
          bid_request: @bid_request
        }
      end
    else
      {
        success: false,
        message: "Failed to accept winning bid",
        bid_request: @bid_request
      }
    end
  end
  
  # Distribute lead to the winning bidder
  def distribute_to_winning_bidder(winning_bid)
    return { success: false, message: "No lead available" } unless @lead
    
    # Find the campaign distribution
    campaign_distribution = @campaign.campaign_distributions.find_by(distribution: winning_bid.distribution)
    return { success: false, message: "Campaign distribution not found" } unless campaign_distribution
    
    # Create a distribution service
    distribution_service = LeadDistributionService.new(@lead)
    
    # Distribute to the specific distribution
    result = distribution_service.distribute_to_specific!(campaign_distribution)
    
    # Update lead status based on result
    if result[:success]
      @lead.update(status: :distributed)
    else
      @lead.update(status: :error, error_message: result[:error])
    end
    
    result
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
    bid = Bid.create!(
      bid_request: @bid_request,
      distribution: distribution,
      amount: bid_amount,
      account: @bid_request.account,
      status: :pending
    )
    
    # Record bid received activity if we have a lead
    if @lead && @lead_activity_service
      @lead_activity_service.record_bid_received(@lead, bid, {
        distribution_name: distribution.name,
        distribution_type: distribution.integration_type
      })
    end
    
    bid
  end
end