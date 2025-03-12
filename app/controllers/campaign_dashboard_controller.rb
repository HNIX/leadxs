class CampaignDashboardController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @campaigns = Campaign.order(created_at: :desc)
    
    # Get date range for filtering
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago.to_date
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.today
    
    # Get period type for time-series data (hourly, daily, weekly, monthly)
    @period_type = params[:period_type].present? ? params[:period_type] : 'daily'
    
    # Filter by campaign if specified
    @selected_campaign = params[:campaign_id].present? ? Campaign.find(params[:campaign_id]) : nil
    
    # Filter by source - currently not functional since BidAnalyticSnapshot doesn't have source_id
    # @selected_source = params[:source_id].present? ? current_account.sources.find(params[:source_id]) : nil
    @selected_source = nil
    
    # Check if we have any analytics data
    snapshot_count = BidAnalyticSnapshot.where(account_id: current_account.id).count
    Rails.logger.info "DEBUG: Found #{snapshot_count} total BidAnalyticSnapshot records for this account"
    
    # Get analytics data based on filters
    fetch_analytics_data
    
    # Log the results for debugging
    Rails.logger.info "DEBUG: @snapshots.count = #{@snapshots.count}"
    Rails.logger.info "DEBUG: @total_bids = #{@total_bids}"
    Rails.logger.info "DEBUG: @accepted_bids = #{@accepted_bids}"
    Rails.logger.info "DEBUG: @total_revenue = #{@total_revenue}"
    Rails.logger.info "DEBUG: @avg_bid_amount = #{@avg_bid_amount}"
    
    # Get top performing campaigns
    @top_campaigns = get_top_campaigns_by_revenue(@start_date, @end_date, 5)
    Rails.logger.info "DEBUG: @top_campaigns.count = #{@top_campaigns.count}"
    
    # Get top sources
    @top_sources = get_top_sources_by_leads(@start_date, @end_date, 5)
    Rails.logger.info "DEBUG: @top_sources.count = #{@top_sources.count}"
    
    # Calculate comparison metrics (vs previous period)
    calculate_comparison_metrics
    
    # If we don't have any real data, generate fallback metrics
    if @snapshots.empty? && @total_bids == 0
      Rails.logger.info "DEBUG: No real data found, generating fallback metrics"
      
      # Check if we should use sample data for testing
      if Rails.env.development? && params[:sample_data].present?
        generate_sample_data
      else
        generate_fallback_metrics
      end
    end
  end
  
  private
  
  def fetch_analytics_data
    # Initialize default values for all metrics - these will be used if no data is found
    @total_bids = 0
    @accepted_bids = 0
    @total_revenue = 0
    @avg_bid_amount = 0
    @acceptance_rate = 0
    @total_cost = 0
    @total_profit = 0
    @profit_margin = 0
    @roi = 0
    @time_series_data = { labels: [], total_bids: [], accepted_bids: [], avg_bid_amount: [], total_revenue: [] }
    
    # Base query for filtering analytics data
    query = BidAnalyticSnapshot.where(period_type: @period_type)
                            .where('period_start >= ? AND period_end <= ?', @start_date.beginning_of_day, @end_date.end_of_day)
                            .where(account_id: current_account.id)
    
    # Apply campaign filter if selected
    query = query.where(campaign_id: @selected_campaign.id) if @selected_campaign.present?
    
    # We can't filter by source directly since there's no source_id column
    # This would require joining with related tables or filtering metrics in memory
    
    # Get aggregated data for the main metrics
    @snapshots = query.order(period_start: :asc)
    
    # Prepare time-series data for charts
    @time_series_data = {
      labels: @snapshots.map { |s| format_period_label(s) },
      total_bids: @snapshots.map(&:total_bids),
      accepted_bids: @snapshots.map(&:accepted_bids),
      avg_bid_amount: @snapshots.map(&:avg_bid_amount),
      total_revenue: @snapshots.map(&:total_revenue)
    }
    
    # Calculate summary metrics
    @total_bids = @snapshots.sum(:total_bids)
    @accepted_bids = @snapshots.sum(:accepted_bids)
    @total_revenue = @snapshots.sum(:total_revenue)
    # Calculate weighted average bid amount
    if @snapshots.any? && @total_bids > 0
      weighted_sum = @snapshots.map { |s| s.avg_bid_amount * s.total_bids }.sum
      @avg_bid_amount = weighted_sum / @total_bids
    else
      @avg_bid_amount = 0
    end
    @acceptance_rate = @total_bids > 0 ? (@accepted_bids.to_f / @total_bids * 100).round(2) : 0
    
    # Calculate profit margins (assuming we have cost data - if not this will be an estimate)
    # For demonstration, we'll assume a 70% profit margin on revenue
    @total_cost = @total_revenue * 0.3
    @total_profit = @total_revenue - @total_cost
    @profit_margin = @total_revenue > 0 ? (@total_profit / @total_revenue * 100).round(2) : 0
    
    # ROI calculation (Return on Investment)
    @roi = @total_cost > 0 ? ((@total_revenue - @total_cost) / @total_cost * 100).round(2) : 0
  end
  
  def calculate_comparison_metrics
    # Initialize defaults for comparison metrics
    @total_bids_change = 0
    @acceptance_rate_change = 0
    @total_revenue_change = 0
    @avg_bid_amount_change = 0
    
    # Calculate the previous period for comparison
    previous_period_length = (@end_date - @start_date).to_i
    previous_start_date = @start_date - previous_period_length.days
    previous_end_date = @start_date - 1.day
    
    # Get data for previous period
    previous_query = BidAnalyticSnapshot.where(period_type: @period_type)
                                     .where('period_start >= ? AND period_end <= ?', previous_start_date.beginning_of_day, previous_end_date.end_of_day)
                                     .where(account_id: current_account.id)
    
    # Apply same campaign filter as current period
    previous_query = previous_query.where(campaign_id: @selected_campaign.id) if @selected_campaign.present?
    # We don't have source_id in the table, so can't filter by source
    
    previous_snapshots = previous_query.order(period_start: :asc)
    
    # Calculate previous period metrics
    previous_total_bids = previous_snapshots.sum(:total_bids)
    previous_accepted_bids = previous_snapshots.sum(:accepted_bids)
    previous_total_revenue = previous_snapshots.sum(:total_revenue)
    # Calculate weighted average bid amount for previous period
    if previous_snapshots.any? && previous_total_bids > 0
      weighted_sum = previous_snapshots.map { |s| s.avg_bid_amount * s.total_bids }.sum
      previous_avg_bid_amount = weighted_sum / previous_total_bids
    else
      previous_avg_bid_amount = 0
    end
    
    # Calculate percentage changes
    @total_bids_change = calculate_percentage_change(previous_total_bids, @total_bids)
    @acceptance_rate_change = calculate_percentage_change(
      (previous_accepted_bids.to_f / previous_total_bids * 100 rescue 0), 
      @acceptance_rate
    )
    @total_revenue_change = calculate_percentage_change(previous_total_revenue, @total_revenue)
    @avg_bid_amount_change = calculate_percentage_change(previous_avg_bid_amount, @avg_bid_amount)
  end
  
  def get_top_campaigns_by_revenue(start_date, end_date, limit = 5)
    BidAnalyticSnapshot.select('campaign_id, SUM(total_revenue) as total_revenue, SUM(total_bids) as total_bids, SUM(accepted_bids) as accepted_bids')
                     .where(period_type: @period_type)
                     .where('period_start >= ? AND period_end <= ?', start_date.beginning_of_day, end_date.end_of_day)
                     .where(account_id: current_account.id)
                     .where.not(campaign_id: nil)
                     .group(:campaign_id)
                     .order('total_revenue DESC')
                     .limit(limit)
                     .map do |snapshot|
                       campaign = Campaign.find_by(id: snapshot.campaign_id)
                       next unless campaign
                       
                       {
                         id: campaign.id,
                         name: campaign.name,
                         total_revenue: snapshot.total_revenue,
                         total_bids: snapshot.total_bids,
                         accepted_bids: snapshot.accepted_bids,
                         acceptance_rate: snapshot.total_bids > 0 ? (snapshot.accepted_bids.to_f / snapshot.total_bids * 100).round(2) : 0
                       }
                     end.compact
  end
  
  def get_top_sources_by_leads(start_date, end_date, limit = 5)
    # Since we don't have source_id in the BidAnalyticSnapshot model,
    # we need to get this data from a different way
    # For now, we'll get the top sources based on lead counts in the system
    
    sources = Source.joins(:leads)
                           .where(leads: { created_at: start_date.beginning_of_day..end_date.end_of_day })
                           .group('sources.id')
                           .select('sources.*, COUNT(leads.id) as leads_count')
                           .order('leads_count DESC')
                           .limit(limit)
    
    sources.map do |source|
      # Count accepted/distributed leads
      accepted_count = source.leads.where(created_at: start_date.beginning_of_day..end_date.end_of_day, status: :distributed).count
      total_count = source.leads_count.to_i
      
      # Get any bids associated with leads from this source
      lead_ids = source.leads.where(created_at: start_date.beginning_of_day..end_date.end_of_day).pluck(:id)
      total_revenue = Bid.joins(:bid_request)
                        .where(bid_requests: { lead_id: lead_ids })
                        .where(status: :accepted)
                        .sum(:amount)
      
      {
        id: source.id,
        name: source.name,
        total_bids: total_count,
        accepted_bids: accepted_count,
        acceptance_rate: total_count > 0 ? (accepted_count.to_f / total_count * 100).round(2) : 0,
        total_revenue: total_revenue
      }
    end
  end
  
  def calculate_percentage_change(previous_value, current_value)
    return 0 if previous_value.to_f == 0 && current_value.to_f == 0
    return 100 if previous_value.to_f == 0 && current_value.to_f > 0
    return -100 if previous_value.to_f > 0 && current_value.to_f == 0
    
    ((current_value.to_f - previous_value.to_f) / previous_value.to_f * 100).round(2)
  end
  
  def format_period_label(snapshot)
    case snapshot.period_type
    when 'hourly'
      snapshot.period_start.strftime('%H:%M')
    when 'daily'
      snapshot.period_start.strftime('%b %d')
    when 'weekly'
      "#{snapshot.period_start.strftime('%b %d')}-#{snapshot.period_end.strftime('%b %d')}"
    when 'monthly'
      snapshot.period_start.strftime('%b %Y')
    else
      snapshot.period_start.strftime('%b %d')
    end
  end
  
  # Generate fallback metrics when we don't have analytics data
  def generate_fallback_metrics
    # Query leads and bids directly to generate metrics
    leads_scope = Lead.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
    
    # Filter by campaign if selected
    leads_scope = leads_scope.where(campaign_id: @selected_campaign.id) if @selected_campaign.present?
    
    # Count total leads
    @total_bids = leads_scope.count
    
    # Count distributed leads (successful)
    @accepted_bids = leads_scope.where(status: :distributed).count
    
    # Calculate acceptance rate
    @acceptance_rate = @total_bids > 0 ? (@accepted_bids.to_f / @total_bids * 100).round(2) : 0
    
    # Get all bids related to these leads
    lead_ids = leads_scope.pluck(:id)
    bids = Bid.joins(:bid_request).where(bid_requests: { lead_id: lead_ids }).where(status: :accepted)
    
    # Calculate revenue
    @total_revenue = bids.sum(:amount)
    
    # Calculate average bid amount
    @avg_bid_amount = bids.any? ? (bids.sum(:amount) / bids.count).round(2) : 0
    
    # Calculate profit metrics (assuming same 70% margin)
    @total_cost = @total_revenue * 0.3
    @total_profit = @total_revenue - @total_cost
    @profit_margin = @total_revenue > 0 ? (@total_profit / @total_revenue * 100).round(2) : 0
    @roi = @total_cost > 0 ? ((@total_revenue - @total_cost) / @total_cost * 100).round(2) : 0
    
    # For time series data, generate sample data points
    generate_fallback_time_series(@start_date, @end_date)
    
    # Set comparison metrics to 0 since we don't have historic data
    @total_bids_change = 0
    @acceptance_rate_change = 0
    @total_revenue_change = 0
    @avg_bid_amount_change = 0
  end
  
  # Generate time series data for charts when analytics data is missing
  def generate_fallback_time_series(start_date, end_date)
    days = (end_date - start_date).to_i + 1
    
    # Generate daily data points
    labels = []
    total_bids_data = []
    accepted_bids_data = []
    revenue_data = []
    bid_amount_data = []
    
    # For each day in the range
    days.times do |i|
      current_date = start_date + i.days
      labels << current_date.strftime('%b %d')
      
      # Get metrics for this day
      daily_leads = Lead.where(created_at: current_date.beginning_of_day..current_date.end_of_day)
      daily_total = daily_leads.count
      daily_accepted = daily_leads.where(status: :distributed).count
      
      lead_ids = daily_leads.pluck(:id)
      daily_bids = Bid.joins(:bid_request).where(bid_requests: { lead_id: lead_ids }).where(status: :accepted)
      daily_revenue = daily_bids.sum(:amount)
      daily_avg_amount = daily_bids.any? ? (daily_bids.sum(:amount) / daily_bids.count) : 0
      
      total_bids_data << daily_total
      accepted_bids_data << daily_accepted
      revenue_data << daily_revenue
      bid_amount_data << daily_avg_amount
    end
    
    # Create time series data for charts
    @time_series_data = {
      labels: labels,
      total_bids: total_bids_data,
      accepted_bids: accepted_bids_data, 
      avg_bid_amount: bid_amount_data,
      total_revenue: revenue_data
    }
  end
  
  # Generate sample data for easy testing in development
  def generate_sample_data
    # Set sample summary metrics
    @total_bids = 1250
    @accepted_bids = 875
    @acceptance_rate = 70.0
    @total_revenue = 8750.50
    @avg_bid_amount = 10.35
    @total_cost = 2625.15
    @total_profit = 6125.35
    @profit_margin = 70.0
    @roi = 233.3
    
    # Set sample comparison metrics
    @total_bids_change = 12.5
    @acceptance_rate_change = 3.2
    @total_revenue_change = 15.8
    @avg_bid_amount_change = -2.3
    
    # Generate sample time series data
    days = (@end_date - @start_date).to_i + 1
    labels = []
    total_bids_data = []
    accepted_bids_data = []
    revenue_data = []
    avg_bid_data = []
    
    # Create random but realistic looking time series data
    days.times do |i|
      current_date = @start_date + i.days
      labels << current_date.strftime('%b %d')
      
      # Base values with some randomness
      daily_bids = rand(30..60)
      acceptance_rate = rand(60..80) / 100.0
      daily_accepted = (daily_bids * acceptance_rate).round
      daily_avg_amount = rand(8.0..12.0).round(2)
      daily_revenue = (daily_accepted * daily_avg_amount).round(2)
      
      total_bids_data << daily_bids
      accepted_bids_data << daily_accepted
      revenue_data << daily_revenue
      avg_bid_data << daily_avg_amount
    end
    
    @time_series_data = {
      labels: labels,
      total_bids: total_bids_data,
      accepted_bids: accepted_bids_data,
      avg_bid_amount: avg_bid_data,
      total_revenue: revenue_data
    }
    
    # Generate sample top campaigns
    @top_campaigns = []
    5.times do |i|
      campaign = @campaigns[i % @campaigns.count]
      next unless campaign
      
      @top_campaigns << {
        id: campaign.id,
        name: campaign.name,
        total_bids: 200 - (i * 30),
        accepted_bids: 140 - (i * 20),
        acceptance_rate: 70.0 - (i * 3),
        total_revenue: 1750.0 - (i * 250)
      }
    end
    
    # Generate sample top sources
    @top_sources = []
    source_names = ['Web Form', 'API Integration', 'Partner Network', 'Email Campaign', 'Paid Search']
    5.times do |i|
      @top_sources << {
        id: i + 1,
        name: source_names[i],
        total_bids: 180 - (i * 25),
        accepted_bids: 126 - (i * 16),
        acceptance_rate: 70.0 - (i * 2),
        total_revenue: 1575.0 - (i * 220)
      }
    end
  end
end