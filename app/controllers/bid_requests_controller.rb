class BidRequestsController < ApplicationController
  before_action :set_bid_request, only: [:show, :edit, :update, :destroy]
  
  def index
    @pagy, @bid_requests = pagy(current_account.bid_requests.recent)
  end
  
  def show
    @bids = @bid_request.bids.includes(:distribution).highest_first
  end
  
  def new
    @bid_request = current_account.bid_requests.new
  end
  
  def create
    @bid_request = current_account.bid_requests.new(bid_request_params)
    
    if @bid_request.save
      redirect_to @bid_request, notice: "Bid request was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @bid_request.update(bid_request_params)
      redirect_to @bid_request, notice: "Bid request was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @bid_request.destroy
    redirect_to bid_requests_path, notice: "Bid request was successfully deleted."
  end
  
  # POST /bid_requests/:id/solicit_bids
  def solicit_bids
    @bid_request = current_account.bid_requests.find(params[:id])
    
    if @bid_request.expired?
      redirect_to @bid_request, alert: "Cannot solicit bids for an expired bid request."
      return
    end
    
    # Find eligible distributions
    eligible_distributions = @bid_request.campaign.eligible_distributions_for_bidding(@bid_request.anonymized_data)
    
    # Request bids asynchronously from each distribution
    eligible_distributions.each do |distribution|
      BidRequestJob.perform_later(@bid_request.id, distribution.id)
    end
    
    redirect_to @bid_request, notice: "Bid solicitation started. Bids will appear as they are received."
  end
  
  # POST /bid_requests/:id/complete
  def complete_bidding
    @bid_request = current_account.bid_requests.find(params[:id])
    
    if @bid_request.expired?
      redirect_to @bid_request, alert: "Cannot complete bidding for an expired bid request."
      return
    end
    
    # Find the winning bid
    winning_bid = @bid_request.winning_bid
    
    if winning_bid.nil?
      redirect_to @bid_request, alert: "No bids received yet."
      return
    end
    
    # Accept the winning bid
    if winning_bid.accept!
      redirect_to @bid_request, notice: "Bidding completed. Winning bid: #{number_to_currency(winning_bid.amount)} from #{winning_bid.distribution.name}"
    else
      redirect_to @bid_request, alert: "Failed to accept the winning bid."
    end
  end
  
  # POST /bid_requests/:id/expire
  def expire
    @bid_request = current_account.bid_requests.find(params[:id])
    
    if @bid_request.update(status: :expired)
      # Mark all pending bids as expired
      @bid_request.bids.pending.update_all(status: :expired)
      redirect_to @bid_request, notice: "Bid request marked as expired."
    else
      redirect_to @bid_request, alert: "Could not expire the bid request."
    end
  end
  
  private
  
  def set_bid_request
    @bid_request = current_account.bid_requests.find(params[:id])
  end
  
  def bid_request_params
    params.require(:bid_request).permit(:campaign_id, :status, :expires_at, anonymized_data: {})
  end
end