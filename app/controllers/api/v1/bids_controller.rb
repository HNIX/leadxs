class Api::V1::BidsController < Api::BaseController
  # POST /api/v1/bids
  # Create a bid in response to a bid request
  def create
    # Find bid request by unique_id
    bid_request = BidRequest.find_by(unique_id: params[:bid_request_id])
    
    if bid_request.nil?
      render json: { error: "Bid request not found" }, status: :not_found
      return
    end
    
    if bid_request.expired?
      render json: { error: "Bid request has expired" }, status: :unprocessable_entity
      return
    end
    
    # Find distribution - must be owned by current user's account
    distribution = current_account.distributions.find_by(id: params[:distribution_id])
    
    if distribution.nil?
      render json: { error: "Distribution not found" }, status: :not_found
      return
    end
    
    # Check if distribution already placed a bid for this request
    existing_bid = bid_request.bids.find_by(distribution: distribution)
    if existing_bid.present?
      render json: { error: "Distribution has already placed a bid for this request" }, status: :unprocessable_entity
      return
    end
    
    # Create the bid
    bid = Bid.new(
      bid_request: bid_request,
      distribution: distribution,
      amount: params[:amount],
      account: current_account,
      status: :pending
    )
    
    if bid.save
      render json: {
        id: bid.id,
        bid_request_id: bid_request.id,
        amount: bid.amount,
        status: bid.status,
        created_at: bid.created_at,
        updated_at: bid.updated_at
      }, status: :created
    else
      render json: { errors: bid.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  # GET /api/v1/bids/:id
  # Check the status of a bid
  def show
    bid = current_account.bids.find_by(id: params[:id])
    
    if bid.nil?
      render json: { error: "Bid not found" }, status: :not_found
      return
    end
    
    render json: {
      id: bid.id,
      bid_request_id: bid.bid_request_id,
      amount: bid.amount,
      status: bid.status,
      created_at: bid.created_at,
      updated_at: bid.updated_at,
      winning_bid: bid.winning_bid?
    }
  end
  
  # GET /api/v1/bid_requests/:bid_request_id/bids
  # List all bids for a bid request
  def index
    bid_request = current_account.bid_requests.find_by(id: params[:bid_request_id])
    
    if bid_request.nil?
      render json: { error: "Bid request not found" }, status: :not_found
      return
    end
    
    bids = bid_request.bids.where(account: current_account)
    
    render json: bids.map { |bid| {
      id: bid.id,
      distribution_id: bid.distribution_id,
      distribution_name: bid.distribution.name,
      amount: bid.amount,
      status: bid.status,
      created_at: bid.created_at,
      updated_at: bid.updated_at,
      winning_bid: bid.winning_bid?
    }}
  end
end