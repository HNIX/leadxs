class BidRequestsController < ApplicationController
  before_action :set_bid_request, only: [:show, :edit, :update, :destroy]
  
  def index
    @pagy, @bid_requests = pagy(BidRequest.recent)
  end
  
  def dashboard
    # Filter by campaign if specified
    if params[:campaign_id].present?
      @campaign = Campaign.find(params[:campaign_id])
      @title = "Bid Request Dashboard for #{@campaign.name}"
      
      # Active bid requests count for this campaign
      @active_bid_requests_count = BidRequest.where(campaign_id: @campaign.id).active.count
      
      # Bids received today for this campaign
      @bids_today_count = Bid.joins(:bid_request)
                            .where(bid_requests: {campaign_id: @campaign.id})
                            .where('bids.created_at > ?', 24.hours.ago)
                            .count
      
      # Average bid amount for this campaign
      @average_bid_amount = Bid.joins(:bid_request)
                              .where(bid_requests: {campaign_id: @campaign.id})
                              .where(status: [:pending, :accepted])
                              .average(:amount) || 0
      
      # Single campaign entry
      @top_campaigns = Campaign.where(id: @campaign.id)
                              .joins(bid_requests: :bids)
                              .select('campaigns.id, campaigns.name, COUNT(bids.id) as bid_count, AVG(bids.amount) as avg_bid_amount')
                              .group('campaigns.id, campaigns.name')
                              .limit(5)
      
      # Top distributions for this campaign
      @top_distributions = Distribution.joins(bids: :bid_request)
                                       .where(bid_requests: {campaign_id: @campaign.id})
                                       .select('distributions.id, distributions.name, 
                                               AVG(bids.amount) as avg_bid_amount,
                                               SUM(CASE WHEN bids.status = 10 THEN 1 ELSE 0 END) * 100.0 / COUNT(bids.id) as win_rate')
                                       .group('distributions.id, distributions.name')
                                       .order('avg_bid_amount DESC')
                                       .limit(5)
      
      # Recent bids for this campaign
      @recent_bids = Bid.joins(:bid_request)
                        .where(bid_requests: {campaign_id: @campaign.id})
                        .includes(:distribution, bid_request: :campaign)
                        .order(created_at: :desc)
                        .limit(10)
    else
      @title = "Bid Request Dashboard"
    
      # Active bid requests count
      @active_bid_requests_count = BidRequest.active.count
      
      # Bids received today
      @bids_today_count = Bid.where('created_at > ?', 24.hours.ago).count
      
      # Average bid amount
      @average_bid_amount = Bid.where(status: [:pending, :accepted]).average(:amount) || 0
      
      # Top campaigns by bid volume
      @top_campaigns = Campaign.joins(bid_requests: :bids)
                                     .select('campaigns.id, campaigns.name, COUNT(bids.id) as bid_count, AVG(bids.amount) as avg_bid_amount')
                                     .group('campaigns.id, campaigns.name')
                                     .order('bid_count DESC')
                                     .limit(5)
      
      # Top distributions by bid amount and win rate
      @top_distributions = Distribution.joins(:bids)
                                        .select('distributions.id, distributions.name, 
                                                AVG(bids.amount) as avg_bid_amount,
                                                SUM(CASE WHEN bids.status = 10 THEN 1 ELSE 0 END) * 100.0 / COUNT(bids.id) as win_rate')
                                        .group('distributions.id, distributions.name')
                                        .order('avg_bid_amount DESC')
                                        .limit(5)
      
      # Recent bids
      @recent_bids = Bid.includes(:distribution, bid_request: :campaign)
                                   .order(created_at: :desc)
                                   .limit(10)
    end
  end
  
  def show
    @bids = @bid_request.bids.includes(:distribution).highest_first
  end
  
  def new
    @bid_request = BidRequest.new
  end
  
  def create
    @bid_request = BidRequest.new(bid_request_params)
    
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
    @bid_request = BidRequest.find(params[:id])
    
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
    @bid_request = BidRequest.find(params[:id])
    
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
    
    # Complete bidding and distribute lead if available
    if @bid_request.lead.present?
      if @bid_request.complete_bidding_and_distribute!
        redirect_to @bid_request, notice: "Bidding completed and lead distributed. Winning bid: #{number_to_currency(winning_bid.amount)} from #{winning_bid.distribution.name}"
      else
        redirect_to @bid_request, alert: "Failed to complete bidding and distribute lead."
      end
    else
      # Just accept the winning bid without lead distribution
      if winning_bid.accept!
        redirect_to @bid_request, notice: "Bidding completed. Winning bid: #{number_to_currency(winning_bid.amount)} from #{winning_bid.distribution.name}"
      else
        redirect_to @bid_request, alert: "Failed to accept the winning bid."
      end
    end
  end
  
  # POST /bid_requests/:id/expire
  def expire
    @bid_request = BidRequest.find(params[:id])
    
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
    @bid_request = BidRequest.find(params[:id])
  end
  
  def bid_request_params
    params.require(:bid_request).permit(:campaign_id, :status, :expires_at, anonymized_data: {})
  end
end