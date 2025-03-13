class Reports::SourcesController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    @campaign_id = params[:campaign_id]
    
    # Build base query for source analytics
    @sources = Source.joins(:leads)
                    .where(leads: { created_at: @date_range[:start]..@date_range[:end] })
                    .group('sources.id')
    
    # Apply campaign filter if specified
    if @campaign_id.present?
      @campaign = Campaign.find(@campaign_id)
      @sources = @sources.where(campaign_id: @campaign_id)
      @title = "Source Performance for #{@campaign.name}"
    else
      @title = "Source Performance Analysis"
    end
    
    # Calculate core metrics for each source
    @source_metrics = calculate_source_metrics(@sources)
    
    # Sort by volume by default, but allow custom sorting
    @sort_by = params[:sort_by] || 'volume'
    @sort_direction = params[:sort_direction] || 'desc'
    
    @source_metrics = sort_source_metrics(@source_metrics, @sort_by, @sort_direction)
    
    # Generate chart data for visualizations
    @chart_data = generate_chart_data(@source_metrics)
    
    # Get top sources by different metrics
    @top_sources_by_volume = @source_metrics.sort_by { |m| -m[:volume] }.take(5)
    @top_sources_by_acceptance = @source_metrics.sort_by { |m| -m[:acceptance_rate] }.take(5)
    @top_sources_by_profit = @source_metrics.sort_by { |m| -m[:profit_per_lead] }.take(5)
  end
  
  def show
    @source = Source.find(params[:id])
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    
    # Get all leads from this source in the date range
    @leads = @source.leads.where(created_at: @date_range[:start]..@date_range[:end])
    
    # Calculate metrics for this source
    @source_metrics = calculate_detailed_source_metrics(@source, @leads)
    
    # Time series data for this source
    @time_series_data = generate_time_series_data(@source, @date_range, @period_type)
    
    # Compliance metrics
    @compliance_metrics = calculate_compliance_metrics(@source, @leads)
  end
  
  private
  
  def get_date_range(period_type)
    case period_type
    when 'hourly'
      end_date = Time.current
      start_date = end_date - 24.hours
    when 'daily'
      end_date = Date.current.end_of_day
      start_date = (end_date - 30.days).beginning_of_day
    when 'weekly'
      end_date = Date.current.end_of_week.end_of_day
      start_date = (end_date - 12.weeks).beginning_of_week.beginning_of_day
    when 'monthly'
      end_date = Date.current.end_of_month.end_of_day
      start_date = (end_date - 12.months).beginning_of_month.beginning_of_day
    else
      end_date = Date.current.end_of_day
      start_date = (end_date - 30.days).beginning_of_day
    end
    
    { start: start_date, end: end_date }
  end
  
  def calculate_source_metrics(sources)
    sources.map do |source|
      # Get all leads from this source in the date range
      leads = source.leads.where(created_at: @date_range[:start]..@date_range[:end])
      
      # Count leads
      lead_volume = leads.count
      
      # Count accepted leads (those with successful bids)
      accepted_leads = leads.joins(:bid_request).where(bid_requests: { status: 'accepted' }).count
      
      # Calculate acceptance rate
      acceptance_rate = lead_volume > 0 ? (accepted_leads.to_f / lead_volume * 100).round(2) : 0
      
      # Get successful bid requests and calculate average bid amount
      bid_requests = BidRequest.where(lead_id: leads.select(:id))
      successful_bids = Bid.where(bid_request_id: bid_requests.select(:id), status: 'accepted')
      avg_bid_amount = successful_bids.average(:amount).to_f.round(2)
      
      # Compliance metrics
      compliance_count = ComplianceRecord.where(record_type: 'Lead', record_id: leads.select(:id)).count
      compliance_rate = lead_volume > 0 ? (compliance_count.to_f / lead_volume * 100).round(2) : 0
      
      # Profit calculations
      total_revenue = successful_bids.sum(:amount).to_f.round(2)
      total_cost = source.calculate_revenue(lead_volume)
      total_profit = source.calculate_profit(avg_bid_amount, lead_volume).round(2)
      profit_per_lead = lead_volume > 0 ? (total_profit / lead_volume).round(2) : 0
      
      {
        id: source.id,
        name: source.name,
        company_name: source.company.name,
        volume: lead_volume,
        accepted_leads: accepted_leads,
        acceptance_rate: acceptance_rate,
        avg_bid_amount: avg_bid_amount,
        compliance_rate: compliance_rate,
        total_revenue: total_revenue,
        total_cost: total_cost,
        total_profit: total_profit,
        profit_per_lead: profit_per_lead
      }
    end
  end
  
  def sort_source_metrics(metrics, sort_by, direction)
    sorted = case sort_by
    when 'volume'
      metrics.sort_by { |m| m[:volume] }
    when 'acceptance_rate'
      metrics.sort_by { |m| m[:acceptance_rate] }
    when 'avg_bid_amount'
      metrics.sort_by { |m| m[:avg_bid_amount] }
    when 'compliance_rate'
      metrics.sort_by { |m| m[:compliance_rate] }
    when 'profit_per_lead'
      metrics.sort_by { |m| m[:profit_per_lead] }
    else
      metrics.sort_by { |m| m[:volume] }
    end
    
    direction == 'asc' ? sorted : sorted.reverse
  end
  
  def generate_chart_data(source_metrics)
    # If no sources with metrics, return empty data structure
    if source_metrics.empty?
      return {
        volume: { labels: [], data: [] },
        acceptance_rate: { labels: [], data: [] },
        avg_bid_amount: { labels: [], data: [] },
        compliance_rate: { labels: [], data: [] },
        profit_per_lead: { labels: [], data: [] }
      }
    end
    
    # Limit to top 10 sources for better chart readability if we have more than 10
    chart_metrics = source_metrics
    if source_metrics.length > 10
      # Use the sort criteria from the controller to determine which metrics to show
      chart_metrics = case @sort_by
      when 'volume'
        source_metrics.sort_by { |m| -m[:volume] }
      when 'acceptance_rate'
        source_metrics.sort_by { |m| -m[:acceptance_rate] }
      when 'avg_bid_amount'
        source_metrics.sort_by { |m| -m[:avg_bid_amount] }
      when 'compliance_rate'
        source_metrics.sort_by { |m| -m[:compliance_rate] }
      when 'profit_per_lead'
        source_metrics.sort_by { |m| -m[:profit_per_lead] }
      else
        source_metrics.sort_by { |m| -m[:volume] }
      end.take(10)
    end
    
    {
      volume: {
        labels: chart_metrics.map { |m| m[:name] },
        data: chart_metrics.map { |m| m[:volume] }
      },
      acceptance_rate: {
        labels: chart_metrics.map { |m| m[:name] },
        data: chart_metrics.map { |m| m[:acceptance_rate] }
      },
      avg_bid_amount: {
        labels: chart_metrics.map { |m| m[:name] },
        data: chart_metrics.map { |m| m[:avg_bid_amount] }
      },
      compliance_rate: {
        labels: chart_metrics.map { |m| m[:name] },
        data: chart_metrics.map { |m| m[:compliance_rate] }
      },
      profit_per_lead: {
        labels: chart_metrics.map { |m| m[:name] },
        data: chart_metrics.map { |m| m[:profit_per_lead] }
      }
    }
  end
  
  def calculate_detailed_source_metrics(source, leads)
    # Count all leads
    lead_volume = leads.count
    
    # Get bid requests and bids
    bid_requests = BidRequest.where(lead_id: leads.select(:id))
    bids = Bid.where(bid_request_id: bid_requests.select(:id))
    accepted_bids = bids.where(status: 'accepted')
    
    # Basic metrics
    accepted_lead_count = bid_requests.where(status: 'accepted').count
    acceptance_rate = lead_volume > 0 ? (accepted_lead_count.to_f / lead_volume * 100).round(2) : 0
    
    # Bid amount metrics
    avg_bid_amount = accepted_bids.average(:amount).to_f.round(2)
    max_bid_amount = accepted_bids.maximum(:amount).to_f.round(2)
    min_bid_amount = accepted_bids.minimum(:amount).to_f.round(2)
    
    # Calculate revenue and profit
    total_revenue = accepted_bids.sum(:amount).to_f.round(2)
    total_cost = source.calculate_revenue(lead_volume)
    total_profit = source.calculate_profit(avg_bid_amount, lead_volume).round(2)
    profit_per_lead = lead_volume > 0 ? (total_profit / lead_volume).round(2) : 0
    roi = total_cost > 0 ? (total_profit / total_cost * 100).round(2) : 0
    
    # Response time metrics
    avg_response_time = bids.average('EXTRACT(EPOCH FROM (created_at - bid_request.created_at))').to_f.round(2) rescue nil
    
    {
      volume: lead_volume,
      accepted_leads: accepted_lead_count,
      acceptance_rate: acceptance_rate,
      avg_bid_amount: avg_bid_amount,
      max_bid_amount: max_bid_amount,
      min_bid_amount: min_bid_amount,
      total_revenue: total_revenue,
      total_cost: total_cost,
      total_profit: total_profit,
      profit_per_lead: profit_per_lead,
      roi: roi,
      avg_response_time: avg_response_time
    }
  end
  
  def generate_time_series_data(source, date_range, period_type)
    # Initialize time periods based on period type
    time_periods = case period_type
    when 'hourly'
      (date_range[:start].to_i..date_range[:end].to_i).step(1.hour).map { |t| Time.at(t) }
    when 'daily'
      (date_range[:start].to_date..date_range[:end].to_date).map { |d| d }
    when 'weekly'
      start_week = date_range[:start].beginning_of_week.to_date
      end_week = date_range[:end].end_of_week.to_date
      (start_week..end_week).step(7).map { |d| d }
    when 'monthly'
      start_month = date_range[:start].beginning_of_month.to_date
      end_month = date_range[:end].end_of_month.to_date
      current = start_month
      months = []
      while current <= end_month
        months << current
        current = current.next_month.beginning_of_month
      end
      months
    end
    
    # Initialize data arrays
    labels = []
    volume_data = []
    acceptance_rate_data = []
    avg_bid_amount_data = []
    
    # Generate data for each time period
    time_periods.each do |period_start|
      period_end = case period_type
      when 'hourly'
        period_start + 1.hour
      when 'daily'
        period_start.end_of_day
      when 'weekly'
        period_start.end_of_week
      when 'monthly'
        period_start.end_of_month
      end
      
      # Format label based on period type
      label = case period_type
      when 'hourly' then period_start.strftime("%H:%M")
      when 'daily' then period_start.strftime("%b %d")
      when 'weekly' then "W#{period_start.strftime('%U')}"
      when 'monthly' then period_start.strftime("%b %Y")
      end
      
      # Get leads for this period
      period_leads = source.leads.where(created_at: period_start..period_end)
      lead_count = period_leads.count
      
      # Get accepted leads
      accepted_leads = period_leads.joins(:bid_request).where(bid_requests: { status: 'accepted' }).count
      
      # Calculate acceptance rate
      period_acceptance_rate = lead_count > 0 ? (accepted_leads.to_f / lead_count * 100).round(2) : 0
      
      # Calculate average bid amount
      bid_requests = BidRequest.where(lead_id: period_leads.select(:id))
      successful_bids = Bid.where(bid_request_id: bid_requests.select(:id), status: 'accepted')
      period_avg_bid_amount = successful_bids.average(:amount).to_f.round(2)
      
      # Add data to arrays
      labels << label
      volume_data << lead_count
      acceptance_rate_data << period_acceptance_rate
      avg_bid_amount_data << period_avg_bid_amount
    end
    
    {
      labels: labels,
      volume: volume_data,
      acceptance_rate: acceptance_rate_data,
      avg_bid_amount: avg_bid_amount_data
    }
  end
  
  def calculate_compliance_metrics(source, leads)
    total_leads = leads.count
    
    # Consent records
    consent_records = ConsentRecord.where(lead_id: leads.select(:id))
    consent_count = consent_records.count
    consent_rate = total_leads > 0 ? (consent_count.to_f / total_leads * 100).round(2) : 0
    
    # Data access records
    data_access_records = DataAccessRecord.where(record_type: 'Lead', record_id: leads.select(:id))
    data_access_count = data_access_records.count
    
    # Compliance records
    compliance_records = ComplianceRecord.where(record_type: 'Lead', record_id: leads.select(:id))
    compliance_count = compliance_records.count
    compliance_rate = total_leads > 0 ? (compliance_count.to_f / total_leads * 100).round(2) : 0
    
    {
      total_leads: total_leads,
      consent_count: consent_count,
      consent_rate: consent_rate,
      data_access_count: data_access_count,
      compliance_count: compliance_count,
      compliance_rate: compliance_rate
    }
  end
end