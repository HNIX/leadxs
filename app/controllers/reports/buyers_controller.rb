class Reports::BuyersController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    @campaign_id = params[:campaign_id]
    
    # Build base query for buyer analytics (distributions)
    @distributions = Distribution.joins(:bids)
                           .where(bids: { created_at: @date_range[:start]..@date_range[:end] })
                           .group('distributions.id')
    
    # Apply campaign filter if specified
    if @campaign_id.present?
      @campaign = Campaign.find(@campaign_id)
      campaign_distribution_ids = CampaignDistribution.where(campaign_id: @campaign_id).pluck(:distribution_id)
      @distributions = @distributions.where(id: campaign_distribution_ids)
      @title = "Buyer Performance for #{@campaign.name}"
    else
      @title = "Buyer Performance Analysis"
    end
    
    # Calculate core metrics for each distribution
    @buyer_metrics = calculate_buyer_metrics(@distributions)
    
    # Sort by default, but allow custom sorting
    @sort_by = params[:sort_by] || 'bids_placed'
    @sort_direction = params[:sort_direction] || 'desc'
    
    @buyer_metrics = sort_buyer_metrics(@buyer_metrics, @sort_by, @sort_direction)
    
    # Generate chart data for visualizations
    @chart_data = generate_chart_data(@buyer_metrics)
    
    # Get top buyers by different metrics
    @top_buyers_by_bids = @buyer_metrics.sort_by { |m| -m[:bids_placed] }.take(5)
    @top_buyers_by_win_rate = @buyer_metrics.sort_by { |m| -m[:win_rate] }.take(5)
    @top_buyers_by_avg_amount = @buyer_metrics.sort_by { |m| -m[:avg_bid_amount] }.take(5)
  end
  
  def show
    @distribution = Distribution.find(params[:id])
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    
    # Get bids from this buyer in the date range
    @bids = @distribution.bids.where(created_at: @date_range[:start]..@date_range[:end])
    
    # Calculate detailed metrics
    @buyer_metrics = calculate_detailed_buyer_metrics(@distribution, @bids)
    
    # Get campaigns this buyer is engaged with
    @campaign_metrics = calculate_campaign_engagement(@distribution, @date_range)
    
    # Time series data for this buyer
    @time_series_data = generate_time_series_data(@distribution, @date_range, @period_type)
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
  
  def calculate_buyer_metrics(distributions)
    distributions.map do |distribution|
      # Get bids from this buyer in the date range
      bids = distribution.bids.where(created_at: @date_range[:start]..@date_range[:end])
      
      # Count all bids
      bid_count = bids.count
      
      # Count different bid statuses
      accepted_bids = bids.where(status: 'accepted').count
      rejected_bids = bids.where(status: 'rejected').count
      expired_bids = bids.where(status: 'expired').count
      error_bids = bids.where(status: 'error').count
      
      # Calculate win rate
      win_rate = bid_count > 0 ? (accepted_bids.to_f / bid_count * 100).round(2) : 0
      
      # Calculate average bid amount
      avg_bid_amount = bids.average(:amount).to_f.round(2)
      max_bid_amount = bids.maximum(:amount).to_f.round(2)
      min_bid_amount = bids.minimum(:amount).to_f.round(2)
      
      # Calculate total spend
      total_spend = bids.where(status: 'accepted').sum(:amount).to_f.round(2)
      
      # Calculate response times
      # This assumes bids have a relationship to bid_request that includes timestamps
      bid_requests = BidRequest.joins(:bids).where(bids: { id: bids.select(:id) }).distinct
      avg_response_time = bids.joins(:bid_request)
                             .where.not(bid_request_id: nil)
                             .average('EXTRACT(EPOCH FROM (bids.created_at - bid_requests.created_at))')
                             .to_f.round(2) rescue nil
      
      # Count unique campaigns this buyer has engaged with
      bid_request_campaign_ids = BidRequest.joins(:bids)
                                 .where(bids: { id: bids.select(:id) })
                                 .distinct.pluck(:campaign_id)
      campaign_count = bid_request_campaign_ids.count
      
      {
        id: distribution.id,
        name: distribution.name,
        company_name: distribution.company.name,
        bids_placed: bid_count,
        accepted_bids: accepted_bids,
        rejected_bids: rejected_bids,
        expired_bids: expired_bids,
        error_bids: error_bids,
        win_rate: win_rate,
        avg_bid_amount: avg_bid_amount,
        max_bid_amount: max_bid_amount,
        min_bid_amount: min_bid_amount,
        total_spend: total_spend,
        avg_response_time: avg_response_time,
        campaign_engagement: campaign_count
      }
    end
  end
  
  def sort_buyer_metrics(metrics, sort_by, direction)
    sorted = case sort_by
    when 'bids_placed'
      metrics.sort_by { |m| m[:bids_placed] }
    when 'win_rate'
      metrics.sort_by { |m| m[:win_rate] }
    when 'avg_bid_amount'
      metrics.sort_by { |m| m[:avg_bid_amount] }
    when 'total_spend'
      metrics.sort_by { |m| m[:total_spend] }
    when 'avg_response_time'
      metrics.sort_by { |m| m[:avg_response_time] || Float::INFINITY }
    when 'campaign_engagement'
      metrics.sort_by { |m| m[:campaign_engagement] }
    else
      metrics.sort_by { |m| m[:bids_placed] }
    end
    
    direction == 'asc' ? sorted : sorted.reverse
  end
  
  def generate_chart_data(buyer_metrics)
    # If no buyers with metrics, return empty structure
    if buyer_metrics.empty?
      return {
        bids_placed: { labels: [], data: [] },
        win_rate: { labels: [], data: [] },
        avg_bid_amount: { labels: [], data: [] },
        response_time: { labels: [], data: [] },
        campaign_engagement: { labels: [], data: [] }
      }
    end
    
    # Limit to top 10 buyers for better chart readability if we have more than 10
    chart_metrics = buyer_metrics
    if buyer_metrics.length > 10
      # Use the sort criteria from the controller to determine which metrics to show
      chart_metrics = case @sort_by
      when 'bids_placed'
        buyer_metrics.sort_by { |m| -m[:bids_placed] }
      when 'win_rate'
        buyer_metrics.sort_by { |m| -m[:win_rate] }
      when 'avg_bid_amount'
        buyer_metrics.sort_by { |m| -m[:avg_bid_amount] }
      when 'total_spend'
        buyer_metrics.sort_by { |m| -m[:total_spend] }
      when 'avg_response_time'
        buyer_metrics.sort_by { |m| -(m[:avg_response_time] || 0) }
      when 'campaign_engagement'
        buyer_metrics.sort_by { |m| -m[:campaign_engagement] }
      else
        buyer_metrics.sort_by { |m| -m[:bids_placed] }
      end.take(10)
    end
    
    {
      bids_placed: {
        labels: chart_metrics.map { |m| m[:name] },
        data: chart_metrics.map { |m| m[:bids_placed] }
      },
      win_rate: {
        labels: chart_metrics.map { |m| m[:name] },
        data: chart_metrics.map { |m| m[:win_rate] }
      },
      avg_bid_amount: {
        labels: chart_metrics.map { |m| m[:name] },
        data: chart_metrics.map { |m| m[:avg_bid_amount] }
      },
      response_time: {
        labels: chart_metrics.map { |m| m[:name] },
        data: chart_metrics.map { |m| m[:avg_response_time] || 0 }
      },
      campaign_engagement: {
        labels: chart_metrics.map { |m| m[:name] },
        data: chart_metrics.map { |m| m[:campaign_engagement] }
      }
    }
  end
  
  def calculate_detailed_buyer_metrics(distribution, bids)
    # Count all bids
    bid_count = bids.count
    
    # Count different bid statuses
    accepted_bids = bids.where(status: 'accepted').count
    rejected_bids = bids.where(status: 'rejected').count
    expired_bids = bids.where(status: 'expired').count
    error_bids = bids.where(status: 'error').count
    
    # Calculate win rate and other rates
    win_rate = bid_count > 0 ? (accepted_bids.to_f / bid_count * 100).round(2) : 0
    rejection_rate = bid_count > 0 ? (rejected_bids.to_f / bid_count * 100).round(2) : 0
    expiration_rate = bid_count > 0 ? (expired_bids.to_f / bid_count * 100).round(2) : 0
    error_rate = bid_count > 0 ? (error_bids.to_f / bid_count * 100).round(2) : 0
    
    # Bid amount metrics
    avg_bid_amount = bids.average(:amount).to_f.round(2)
    max_bid_amount = bids.maximum(:amount).to_f.round(2)
    min_bid_amount = bids.minimum(:amount).to_f.round(2)
    
    # Calculate total spend
    total_spend = bids.where(status: 'accepted').sum(:amount).to_f.round(2)
    
    # Calculate response times
    avg_response_time = bids.joins(:bid_request)
                           .where.not(bid_request_id: nil)
                           .average('EXTRACT(EPOCH FROM (bids.created_at - bid_requests.created_at))')
                           .to_f.round(2) rescue nil
    
    # Calculate bid frequency
    earliest_bid = bids.minimum(:created_at)
    latest_bid = bids.maximum(:created_at)
    
    if earliest_bid && latest_bid && earliest_bid != latest_bid
      time_span = (latest_bid - earliest_bid) / 1.hour
      bids_per_hour = time_span > 0 ? (bid_count.to_f / time_span).round(2) : 0
    else
      bids_per_hour = 0
    end
    
    # Calculate bid distribution by time of day
    morning_bids = bids.where("EXTRACT(HOUR FROM created_at) >= 6 AND EXTRACT(HOUR FROM created_at) < 12").count
    afternoon_bids = bids.where("EXTRACT(HOUR FROM created_at) >= 12 AND EXTRACT(HOUR FROM created_at) < 18").count
    evening_bids = bids.where("EXTRACT(HOUR FROM created_at) >= 18 AND EXTRACT(HOUR FROM created_at) < 24").count
    night_bids = bids.where("EXTRACT(HOUR FROM created_at) >= 0 AND EXTRACT(HOUR FROM created_at) < 6").count
    
    {
      bids_placed: bid_count,
      accepted_bids: accepted_bids,
      rejected_bids: rejected_bids,
      expired_bids: expired_bids,
      error_bids: error_bids,
      win_rate: win_rate,
      rejection_rate: rejection_rate,
      expiration_rate: expiration_rate,
      error_rate: error_rate,
      avg_bid_amount: avg_bid_amount,
      max_bid_amount: max_bid_amount,
      min_bid_amount: min_bid_amount,
      total_spend: total_spend,
      avg_response_time: avg_response_time,
      bids_per_hour: bids_per_hour,
      bid_time_distribution: {
        morning: morning_bids,
        afternoon: afternoon_bids,
        evening: evening_bids,
        night: night_bids
      }
    }
  end
  
  def calculate_campaign_engagement(distribution, date_range)
    # Get campaigns this buyer is engaged with
    campaign_distributions = distribution.campaign_distributions
    
    campaign_distributions.map do |cd|
      campaign = cd.campaign
      
      # Get bids for this campaign from this buyer
      bids = Bid.joins(:bid_request)
             .where(distribution_id: distribution.id)
             .where(created_at: date_range[:start]..date_range[:end])
             .where(bid_requests: { campaign_id: campaign.id })
      
      # Count bids
      bid_count = bids.count
      
      # Skip campaigns with no bids in the period
      next if bid_count == 0
      
      # Count accepted bids
      accepted_bids = bids.where(status: 'accepted').count
      
      # Calculate win rate
      win_rate = bid_count > 0 ? (accepted_bids.to_f / bid_count * 100).round(2) : 0
      
      # Calculate average bid amount
      avg_bid_amount = bids.average(:amount).to_f.round(2)
      
      # Calculate total spend
      total_spend = bids.where(status: 'accepted').sum(:amount).to_f.round(2)
      
      # Calculate response time
      avg_response_time = bids.joins(:bid_request)
                             .where.not(bid_request_id: nil)
                             .average('EXTRACT(EPOCH FROM (bids.created_at - bid_requests.created_at))')
                             .to_f.round(2) rescue nil
      
      {
        id: campaign.id,
        name: campaign.name,
        bids_placed: bid_count,
        accepted_bids: accepted_bids,
        win_rate: win_rate,
        avg_bid_amount: avg_bid_amount,
        total_spend: total_spend,
        avg_response_time: avg_response_time
      }
    end.compact.sort_by { |m| -m[:bids_placed] }
  end
  
  def generate_time_series_data(distribution, date_range, period_type)
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
    bids_data = []
    win_rate_data = []
    avg_amount_data = []
    response_time_data = []
    
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
      
      # Get bids for this period
      period_bids = distribution.bids.where(created_at: period_start..period_end)
      bid_count = period_bids.count
      
      # Skip periods with no bids
      if bid_count > 0
        # Count accepted bids
        accepted_bids = period_bids.where(status: 'accepted').count
        
        # Calculate win rate
        period_win_rate = (accepted_bids.to_f / bid_count * 100).round(2)
        
        # Calculate average bid amount
        period_avg_amount = period_bids.average(:amount).to_f.round(2)
        
        # Calculate average response time
        period_avg_response_time = period_bids.joins(:bid_request)
                                          .where.not(bid_request_id: nil)
                                          .average('EXTRACT(EPOCH FROM (bids.created_at - bid_requests.created_at))')
                                          .to_f.round(2) rescue nil
        
        # Add data to arrays
        labels << label
        bids_data << bid_count
        win_rate_data << period_win_rate
        avg_amount_data << period_avg_amount
        response_time_data << period_avg_response_time || 0
      elsif !labels.empty?
        # Add zero values for periods with no bids (but only if we have some data already)
        labels << label
        bids_data << 0
        win_rate_data << 0
        avg_amount_data << 0
        response_time_data << 0
      end
    end
    
    {
      labels: labels,
      bids: bids_data,
      win_rate: win_rate_data,
      avg_amount: avg_amount_data,
      response_time: response_time_data
    }
  end
end