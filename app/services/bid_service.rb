class BidService
  def initialize(lead_or_anonymized_data, campaign)
    @campaign = campaign
    
    if lead_or_anonymized_data.is_a?(Lead)
      @lead = lead_or_anonymized_data
      @anonymized_data = @lead.anonymized_data
    else
      @lead = nil
      @anonymized_data = lead_or_anonymized_data
    end
    
    @bid_request = nil
  end
  
  # Create a bid request and solicit bids from eligible distributions
  def solicit_bids!
    # Determine the account to use
    account = ActsAsTenant.current_tenant || @lead&.account || @campaign.account
    
    # Create a new bid request
    @bid_request = BidRequest.create!(
      account: account,
      campaign: @campaign,
      lead: @lead,
      anonymized_data: @anonymized_data,
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
    
    # Get winning bid
    winning_bid = @bid_request.winning_bid
    
    if winning_bid.nil?
      return {
        success: false,
        message: "No bids received",
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