class Api::V1::BidRequestsController < Api::BaseController
  # GET /api/v1/bid_requests
  # List bid requests for the current account
  def index
    bid_requests = current_account.bid_requests
      .order(created_at: :desc)
      .limit(params[:limit] || 50)
    
    render json: bid_requests.map { |br| bid_request_json(br) }
  end
  
  # GET /api/v1/bid_requests/:id
  # Get details for a specific bid request
  def show
    bid_request = current_account.bid_requests.find_by(id: params[:id])
    
    if bid_request.nil?
      render json: { error: "Bid request not found" }, status: :not_found
      return
    end
    
    render json: bid_request_json(bid_request, include_bids: true)
  end
  
  # POST /api/v1/bid_requests
  # Create a new bid request (usually done through the BidService, this is for testing)
  def create
    campaign = current_account.campaigns.find_by(id: params[:campaign_id])
    
    if campaign.nil?
      render json: { error: "Campaign not found" }, status: :unprocessable_entity
      return
    end
    
    # Create a new bid request
    bid_request = BidRequest.new(
      account: current_account,
      campaign: campaign,
      anonymized_data: params[:anonymized_data],
      status: :pending,
      expires_at: Time.current + (params[:timeout_seconds]&.to_i || campaign.bid_timeout_seconds || 1800).seconds
    )
    
    if bid_request.save
      # Optionally start soliciting bids
      if params[:solicit_bids].to_s == "true"
        # Find eligible distributions
        eligible_distributions = campaign.eligible_distributions_for_bidding(bid_request.anonymized_data)
        
        # Request bids asynchronously from each distribution
        eligible_distributions.each do |distribution|
          BidRequestJob.perform_later(bid_request.id, distribution.id)
        end
      end
      
      render json: bid_request_json(bid_request), status: :created
    else
      render json: { errors: bid_request.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  # POST /api/v1/bid_requests/:id/solicit_bids
  # Manually trigger bid solicitation for a bid request
  def solicit_bids
    bid_request = current_account.bid_requests.find_by(id: params[:id])
    
    if bid_request.nil?
      render json: { error: "Bid request not found" }, status: :not_found
      return
    end
    
    if bid_request.expired?
      render json: { error: "Bid request has expired" }, status: :unprocessable_entity
      return
    end
    
    # Find eligible distributions
    eligible_distributions = bid_request.campaign.eligible_distributions_for_bidding(bid_request.anonymized_data)
    
    # Request bids asynchronously from each distribution
    eligible_distributions.each do |distribution|
      BidRequestJob.perform_later(bid_request.id, distribution.id)
    end
    
    render json: {
      status: "success",
      message: "Bid solicitation started",
      bids_requested: eligible_distributions.size
    }
  end
  
  # POST /api/v1/bid_requests/:id/complete
  # Complete the bidding process and select a winner
  def complete_bidding
    bid_request = current_account.bid_requests.find_by(id: params[:id])
    
    if bid_request.nil?
      render json: { error: "Bid request not found" }, status: :not_found
      return
    end
    
    if bid_request.expired?
      render json: { error: "Bid request has expired" }, status: :unprocessable_entity
      return
    end
    
    # Get winning bid
    winning_bid = bid_request.winning_bid
    
    if winning_bid.nil?
      render json: { error: "No bids received" }, status: :unprocessable_entity
      return
    end
    
    # Accept the winning bid
    if winning_bid.accept!
      render json: {
        message: "Bidding completed successfully",
        winning_bid: {
          id: winning_bid.id,
          distribution_id: winning_bid.distribution_id,
          distribution_name: winning_bid.distribution.name,
          amount: winning_bid.amount
        }
      }
    else
      render json: { error: "Failed to accept the winning bid" }, status: :unprocessable_entity
    end
  end
  
  private
  
  def bid_request_json(bid_request, include_bids: false)
    result = {
      id: bid_request.id,
      unique_id: bid_request.unique_id,
      token: bid_request.unique_id, # Added token for test compatibility
      campaign_id: bid_request.campaign_id,
      campaign_name: bid_request.campaign.name,
      status: bid_request.status,
      expires_at: bid_request.expires_at,
      created_at: bid_request.created_at,
      updated_at: bid_request.updated_at,
      bid_count: bid_request.bids.count
    }
    
    if include_bids
      # Add bids information
      result[:bids] = bid_request.bids.map { |bid| {
        id: bid.id,
        distribution_id: bid.distribution_id,
        distribution_name: bid.distribution.name,
        amount: bid.amount,
        status: bid.status,
        created_at: bid.created_at,
        updated_at: bid.updated_at,
        winning_bid: bid.winning_bid?
      }}
      
      # Add winning bid
      if (winning_bid = bid_request.winning_bid)
        result[:winning_bid] = {
          id: winning_bid.id,
          distribution_id: winning_bid.distribution_id,
          distribution_name: winning_bid.distribution.name,
          amount: winning_bid.amount
        }
      end
    end
    
    result
  end
end