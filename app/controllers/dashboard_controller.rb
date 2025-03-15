class DashboardController < ApplicationController
  before_action :authenticate_user!
  
  def show
    # Load key metrics
    @metrics = {
      leads: {
        total: Lead.count,
        today: Lead.where('created_at >= ?', Date.today.beginning_of_day).count,
        conversion_rate: calculate_lead_conversion_rate
      },
      bids: {
        total: Bid.count,
        today: Bid.where('created_at >= ?', Date.today.beginning_of_day).count,
        average_amount: Bid.average(:amount)&.round(2) || 0,
        win_rate: calculate_bid_win_rate
      },
      campaigns: {
        total: Campaign.count,
        active: Campaign.where(status: 'active').count
      },
      distributions: {
        total: Distribution.count,
        active: CampaignDistribution.where.not(last_used_at: nil).count,
        success_rate: calculate_distribution_success_rate
      }
    }
    
    # Load data needed for dashboard cards
    @active_campaigns_count = Campaign.where(status: 'active').count
    @recent_leads = Lead.all.order(created_at: :desc).limit(10)
    @sources_count = Source.count
    @leads_count = Lead.where('created_at >= ?', 30.days.ago).count
    @bid_count = Bid.where('created_at >= ?', 30.days.ago).count
    @recent_bids = Bid.all.order(created_at: :desc).limit(10)
    @distribution_count = Distribution.where('created_at >= ?', 30.days.ago).count
    @recent_distributions = Distribution.all.order(created_at: :desc).limit(10)
    @distribution_success_rate = calculate_distribution_success_rate
    
    # Load recent activity logs
    begin
      @recent_activities = LeadActivityLog.includes(:lead).order(created_at: :desc).limit(10)
    rescue => e
      Rails.logger.error("Error loading activity logs: #{e.message}")
      @recent_activities = []
    end
    
    # Load recent leads
    @recent_leads = Lead.includes(:campaign, :source).order(created_at: :desc).limit(5)
    
    # Load recent bids
    @recent_bids = Bid.includes(:distribution, bid_request: :lead).order(created_at: :desc).limit(5)
    
    # Load recent campaigns, sources, and distributions for the data management section
    @recent_campaigns = Campaign.order(created_at: :desc).limit(5)
    @recent_sources = Source.includes(:campaign).order(created_at: :desc).limit(5)
    @recent_distributions = Distribution.includes(:campaigns).order(created_at: :desc).limit(5)
    
    # Calculate system health
    @system_health = {
      api_success_rate: calculate_api_success_rate,
      average_response_time: calculate_average_response_time
    }
  end
  
  private
  
  def calculate_lead_conversion_rate
    total_leads = Lead.count
    return 0 if total_leads == 0
    
    converted_leads = Lead.where(status: ['distributed', 'accepted']).count
    (converted_leads.to_f / total_leads * 100).round(1)
  end
  
  def calculate_bid_win_rate
    total_bids = Bid.count
    return 0 if total_bids == 0
    
    winning_bids = Bid.where(status: 'accepted').count
    (winning_bids.to_f / total_bids * 100).round(1)
  end
  
  def calculate_distribution_success_rate
    total_attempts = ApiRequest.where(requestable_type: 'Distribution').count
    return 0 if total_attempts == 0
    
    successful_attempts = ApiRequest.where(requestable_type: 'Distribution').where('response_code >= 200 AND response_code < 300 AND (error IS NULL OR error = \'\')').count
    (successful_attempts.to_f / total_attempts * 100).round(1)
  end
  
  def calculate_api_success_rate
    recent_requests = ApiRequest.where('created_at >= ?', 24.hours.ago).count
    return 100 if recent_requests == 0
    
    successful_requests = ApiRequest.where('created_at >= ?', 24.hours.ago)
                                    .where('response_code >= 200 AND response_code < 300 AND (error IS NULL OR error = \'\')')
                                    .count
    (successful_requests.to_f / recent_requests * 100).round(1)
  end
  
  def calculate_average_response_time
    recent_requests = ApiRequest.where('created_at >= ?', 24.hours.ago)
    return 0 if recent_requests.empty?
    
    # Calculate average response time in milliseconds
    average_time = recent_requests.average(:duration_ms)
    average_time ? average_time.round(0) : 0
  end
end
