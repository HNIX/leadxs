class BidsController < ApplicationController
  before_action :set_bid_request
  before_action :set_bid, only: [:show, :edit, :update, :destroy, :accept, :reject]
  
  def index
    @pagy, @bids = pagy(@bid_request.bids.includes(:distribution).highest_first)
  end
  
  def show
  end
  
  def new
    @bid = @bid_request.bids.new
  end
  
  def create
    @bid = @bid_request.bids.new(bid_params)
    @bid.account = current_account
    
    if @bid.save
      redirect_to [@bid_request, @bid], notice: "Bid was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @bid.update(bid_params)
      redirect_to [@bid_request, @bid], notice: "Bid was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @bid.destroy
    redirect_to bid_request_bids_path(@bid_request), notice: "Bid was successfully deleted."
  end
  
  # POST /bid_requests/:bid_request_id/bids/:id/accept
  def accept
    if @bid_request.expired?
      redirect_to [@bid_request, @bid], alert: "Cannot accept bid for an expired bid request."
      return
    end
    
    if @bid.accept!
      redirect_to @bid_request, notice: "Bid accepted successfully."
    else
      redirect_to [@bid_request, @bid], alert: "Failed to accept the bid."
    end
  end
  
  # POST /bid_requests/:bid_request_id/bids/:id/reject
  def reject
    if @bid.update(status: :rejected)
      redirect_to @bid_request, notice: "Bid rejected successfully."
    else
      redirect_to [@bid_request, @bid], alert: "Failed to reject the bid."
    end
  end
  
  private
  
  def set_bid_request
    @bid_request = current_account.bid_requests.find(params[:bid_request_id])
  end
  
  def set_bid
    @bid = @bid_request.bids.find(params[:id])
  end
  
  def bid_params
    params.require(:bid).permit(:distribution_id, :amount, :status)
  end
end