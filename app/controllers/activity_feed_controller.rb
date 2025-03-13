class ActivityFeedController < ApplicationController
  before_action :authenticate_user!
  
  def index
    # Get campaigns for filter dropdown
    @campaigns = Campaign.order(:name)
    
    # Add total counters for UI badges
    @lead_count = Lead.count
    @bid_count = Bid.count
    @distribution_count = CampaignDistribution.where.not(last_used_at: nil).count
    
    # Build filters
    filter_activities
    filter_leads
    filter_bids
    filter_distributions

    respond_to do |format|
      format.html
      format.json { 
        render json: {
          activities: @activities.as_json(include: [:lead], methods: [:causer_info]),
          leads: @leads.as_json(include: [:campaign, :source]),
          bids: @bids.as_json(include: [:bid_request, :distribution]),
          distributions: @distributions.as_json(include: [:campaign, :distribution])
        }
      }
    end
  end

  private

  def filter_activities
    # Start with base query - using includes without a specific causer type
    activities = LeadActivityLog.includes(:lead).order(created_at: :desc)
    
    # Apply campaign filter if selected
    if params[:campaign_id].present?
      activities = activities.joins(lead: :campaign).where(campaigns: { id: params[:campaign_id] })
    end
    
    # Apply date filter if selected
    if params[:date_range].present?
      case params[:date_range]
      when 'hour'
        activities = activities.where('lead_activity_logs.created_at >= ?', 1.hour.ago)
      when 'today'
        activities = activities.where('lead_activity_logs.created_at >= ?', Date.today.beginning_of_day)
      when 'yesterday'
        activities = activities.where(created_at: Date.yesterday.beginning_of_day..Date.yesterday.end_of_day)
      when 'week'
        activities = activities.where('lead_activity_logs.created_at >= ?', 1.week.ago)
      when 'month'
        activities = activities.where('lead_activity_logs.created_at >= ?', 1.month.ago)
      end
    end
    
    # Apply activity type filter if selected
    if params[:activity_type].present?
      activities = activities.where(activity_type: params[:activity_type])
    end
    
    @activities = activities.limit(20)
  end

  def filter_leads
    # Start with base query
    leads = Lead.includes(:campaign, :source, :bid_request).order(created_at: :desc)
    
    # Apply campaign filter if selected
    if params[:campaign_id].present?
      leads = leads.where(campaign_id: params[:campaign_id])
    end
    
    # Apply date filter
    if params[:date_range].present?
      case params[:date_range]
      when 'hour'
        leads = leads.where('created_at >= ?', 1.hour.ago)
      when 'today'
        leads = leads.where('created_at >= ?', Date.today.beginning_of_day)
      when 'yesterday'
        leads = leads.where(created_at: Date.yesterday.beginning_of_day..Date.yesterday.end_of_day)
      when 'week'
        leads = leads.where('created_at >= ?', 1.week.ago)
      when 'month'
        leads = leads.where('created_at >= ?', 1.month.ago)
      end
    end
    
    # Apply status filter
    if params[:lead_status].present?
      leads = leads.where(status: params[:lead_status])
    end
    
    @leads = leads.limit(10)
  end
  
  def filter_bids
    # Start with base query
    bids = Bid.includes(:bid_request, :distribution).order(created_at: :desc)
    
    # Apply campaign filter if selected
    if params[:campaign_id].present?
      bids = bids.joins(bid_request: :campaign).where(bid_requests: { campaign_id: params[:campaign_id] })
    end
    
    # Apply date filter
    if params[:date_range].present?
      case params[:date_range]
      when 'hour'
        bids = bids.where('bids.created_at >= ?', 1.hour.ago)
      when 'today'
        bids = bids.where('bids.created_at >= ?', Date.today.beginning_of_day)
      when 'yesterday'
        bids = bids.where(created_at: Date.yesterday.beginning_of_day..Date.yesterday.end_of_day)
      when 'week'
        bids = bids.where('bids.created_at >= ?', 1.week.ago)
      when 'month'
        bids = bids.where('bids.created_at >= ?', 1.month.ago)
      end
    end
    
    # Apply status filter
    if params[:bid_status].present?
      bids = bids.where(status: params[:bid_status])
    end
    
    @bids = bids.limit(10)
  end
  
  def filter_distributions
    # Start with base query
    distributions = CampaignDistribution.includes(:campaign, :distribution)
                             .where.not(campaign_distributions: { last_used_at: nil })
                             .order(campaign_distributions: { last_used_at: :desc })
    
    # Apply campaign filter if selected
    if params[:campaign_id].present?
      distributions = distributions.where(campaign_id: params[:campaign_id])
    end
    
    # Apply date filter
    if params[:date_range].present?
      case params[:date_range]
      when 'hour'
        distributions = distributions.where('campaign_distributions.last_used_at >= ?', 1.hour.ago)
      when 'today'
        distributions = distributions.where('campaign_distributions.last_used_at >= ?', Date.today.beginning_of_day)
      when 'yesterday'
        distributions = distributions.where(last_used_at: Date.yesterday.beginning_of_day..Date.yesterday.end_of_day)
      when 'week'
        distributions = distributions.where('campaign_distributions.last_used_at >= ?', 1.week.ago)
      when 'month'
        distributions = distributions.where('campaign_distributions.last_used_at >= ?', 1.month.ago)
      end
    end
    
    @distributions = distributions.limit(10)
  end
end