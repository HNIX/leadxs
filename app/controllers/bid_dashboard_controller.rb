class BidDashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account
  
  def index
    # Filter by campaign if specified
    if params[:campaign_id].present?
      @campaign = Campaign.find(params[:campaign_id])
      @title = "Bid Dashboard for #{@campaign.name}"
      
      # Get the latest metrics filtered by campaign
      @latest_hourly = BidAnalyticSnapshot.hourly.for_campaign(@campaign.id).last
      @latest_daily = BidAnalyticSnapshot.daily.for_campaign(@campaign.id).last
      @latest_weekly = BidAnalyticSnapshot.weekly.for_campaign(@campaign.id).last
      
      # Get time series data for charts
      @hourly_data = BidAnalyticSnapshot.hourly.for_campaign(@campaign.id).last(24)
      @daily_data = BidAnalyticSnapshot.daily.for_campaign(@campaign.id).last(30)
      
      # Set campaign data for this specific campaign
      @campaigns = [@campaign]
      @campaign_data = {
        @campaign.id => {
          name: @campaign.name,
          snapshots: BidAnalyticSnapshot.daily.for_campaign(@campaign.id).last(7)
        }
      }
    else
      # Default behavior without filtering
      @title = "Bid Dashboard"
      
      # Get the latest metrics
      @latest_hourly = BidAnalyticSnapshot.hourly.last
      @latest_daily = BidAnalyticSnapshot.daily.last
      @latest_weekly = BidAnalyticSnapshot.weekly.last
      
      # Get time series data for charts
      @hourly_data = BidAnalyticSnapshot.hourly.last(24)
      @daily_data = BidAnalyticSnapshot.daily.last(30)
      
      # Get campaign and distribution specific data
      @campaigns = Campaign.all
      @campaign_data = {}
      @campaigns.each do |campaign|
        @campaign_data[campaign.id] = {
          name: campaign.name,
          snapshots: BidAnalyticSnapshot.daily.for_campaign(campaign).last(7)
        }
      end 
    end
    
    # Fallbacks if no data exists yet
    @latest_hourly ||= BidAnalyticSnapshot.new(
      total_bids: 0, 
      accepted_bids: 0, 
      rejected_bids: 0, 
      expired_bids: 0, 
      avg_bid_amount: 0, 
      conversion_count: 0, 
      total_revenue: 0,
      metrics: {}
    )
    @latest_daily ||= BidAnalyticSnapshot.new(
      total_bids: 0, 
      accepted_bids: 0, 
      rejected_bids: 0, 
      expired_bids: 0, 
      avg_bid_amount: 0, 
      conversion_count: 0, 
      total_revenue: 0,
      metrics: {}
    )
    @latest_weekly ||= BidAnalyticSnapshot.new(
      total_bids: 0, 
      accepted_bids: 0, 
      rejected_bids: 0, 
      expired_bids: 0, 
      avg_bid_amount: 0, 
      conversion_count: 0, 
      total_revenue: 0,
      metrics: {}
    )
    
    # Prepare data for charts - handle empty data
    @hourly_data = @hourly_data.presence || []
    @daily_data = @daily_data.presence || []
    @bid_volume_data = prepare_time_series_data(@hourly_data, :total_bids)
    @acceptance_rate_data = prepare_time_series_data(@hourly_data, :acceptance_rate)
    @revenue_data = prepare_time_series_data(@daily_data, :total_revenue)
    @avg_bid_data = prepare_time_series_data(@daily_data, :avg_bid_amount)
  end
  
  def real_time
    # Filter by campaign if specified
    if params[:campaign_id].present?
      @campaign = Campaign.find(params[:campaign_id])
      @title = "Real-time Bid Dashboard for #{@campaign.name}"
      
      # Get the latest metrics filtered by campaign
      @latest_hourly = BidAnalyticSnapshot.hourly.for_campaign(@campaign.id).last
      
      # Get only this campaign for the account
      @campaigns = [@campaign]
    else
      @title = "Real-time Bid Dashboard"
      
      # Get the latest metrics for initial display
      @latest_hourly = BidAnalyticSnapshot.hourly.last
      
      # Get all campaigns for the account
      @campaigns = Campaign.all
    end
    
    # Ensure we have dummy data if no real data exists yet
    @latest_hourly ||= BidAnalyticSnapshot.new(
      total_bids: 0,
      accepted_bids: 0,
      rejected_bids: 0,
      expired_bids: 0,
      avg_bid_amount: 0,
      conversion_count: 0,
      total_revenue: 0,
      metrics: {}
    )
    
    # Create empty array if no campaigns exist yet
    @campaigns = [] if @campaigns.nil?
  end
  
  private
  
  def set_account
    @account = current_account
  end
  
  def prepare_time_series_data(snapshots, metric)
    return [] if snapshots.blank?
    
    snapshots.map do |snapshot|
      {
        timestamp: snapshot.period_start.to_i * 1000, # Convert to milliseconds for JS
        value: snapshot.send(metric) || 0
      }
    end
  end
end