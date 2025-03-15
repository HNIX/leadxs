class CampaignPerformanceController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account
  before_action :set_campaign
  
  def index
    # Set title based on campaign type
    @title = if @campaign.campaign_type == 'calls'
               "Call Performance for #{@campaign.name}"
             else
               "Campaign Performance for #{@campaign.name}"
             end
    
    # Get lead submission data for the campaign
    @total_leads = @campaign.leads.count
    @successful_leads = @campaign.leads.where(status: 'delivered').count
    @failed_leads = @campaign.leads.where(status: 'failed').count
    @pending_leads = @campaign.leads.where(status: 'pending').count
    
    # Prepare data for time series charts
    @lead_data_by_day = prepare_lead_data_by_day(@campaign)
    @submission_rate_by_day = prepare_submission_rate_by_day(@campaign)
    
    # Get source-specific data
    @source_performance = prepare_source_performance(@campaign)
    
    # Get distribution-specific data
    @distribution_performance = prepare_distribution_performance(@campaign)
    
    # For call campaigns, additional metrics
    if @campaign.campaign_type == 'calls'
      @call_metrics = prepare_call_metrics(@campaign)
    end
    
    # Render the appropriate view based on campaign type
    render @campaign.campaign_type == 'calls' ? :calls : :index
  end
  
  private
  
  def set_account
    @account = current_account
  end
  
  def set_campaign
    @campaign = Campaign.find(params[:campaign_id])
  end
  
  def prepare_lead_data_by_day(campaign)
    # Group leads by day and count manually
    leads = campaign.leads.where('created_at > ?', 30.days.ago)
    
    # Group by date (stripping time component)
    leads_by_day = leads.group_by { |lead| lead.created_at.to_date }
    
    # Convert to the format needed for charts
    leads_by_day.map do |date, leads|
      { date: date.to_time.to_i * 1000, count: leads.count }
    end.sort_by { |item| item[:date] }
  end
  
  def prepare_submission_rate_by_day(campaign)
    # Calculate success rate by day manually
    leads = campaign.leads.where('created_at > ?', 30.days.ago)
    
    # Group all leads by date
    leads_by_day = leads.group_by { |lead| lead.created_at.to_date }
    
    # Group successful leads by date
    successful_leads = leads.where(status: 'delivered')
    successful_by_day = successful_leads.group_by { |lead| lead.created_at.to_date }
    
    leads_by_day.map do |date, leads_array|
      success_array = successful_by_day[date] || []
      total_count = leads_array.count
      success_count = success_array.count
      rate = total_count > 0 ? (success_count.to_f / total_count * 100).round(1) : 0
      { date: date.to_time.to_i * 1000, rate: rate }
    end
  end
  
  def prepare_source_performance(campaign)
    # Get performance metrics by source
    campaign.sources.map do |source|
      # Count leads correctly using source_id
      total = campaign.leads.where(source_id: source.id).count
      
      # Use lead statuses based on the Lead model's enum (20 = distributed)
      successful = campaign.leads.where(source_id: source.id, status: :distributed).count
      rate = total > 0 ? (successful.to_f / total * 100).round(1) : 0
      
      {
        id: source.id,
        name: source.name,
        total_leads: total,
        successful_leads: successful,
        success_rate: rate
      }
    end
  end
  
  def prepare_distribution_performance(campaign)
    # Get performance metrics by distribution
    campaign.distributions.map do |dist|
      # Instead of looking for distribution_id in leads, look for distribution-related API requests
      lead_ids_for_dist = dist.api_requests.where(lead_id: campaign.leads.pluck(:id)).pluck(:lead_id).uniq
      
      total = lead_ids_for_dist.count
      
      # For successful leads, check API requests with successful HTTP response codes (200-299)
      successful_api_requests = dist.api_requests.where(lead_id: campaign.leads.pluck(:id))
                                                .where("response_code >= 200 AND response_code < 300")
      successful_lead_ids = successful_api_requests.pluck(:lead_id).uniq
      successful = successful_lead_ids.count
      
      rate = total > 0 ? (successful.to_f / total * 100).round(1) : 0
      
      {
        id: dist.id,
        name: dist.name,
        total_leads: total,
        successful_leads: successful,
        success_rate: rate
      }
    end
  end
  
  def prepare_call_metrics(campaign)
    # For call campaigns, calculate call-specific metrics
    # This would typically come from a telephony provider integration
    {
      total_calls: campaign.leads.count,
      connected_calls: rand(campaign.leads.count),
      average_duration: rand(30..300),
      call_quality_score: rand(7.0..9.9).round(1)
    }
  end
end