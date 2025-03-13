class BidReportsController < ApplicationController
  before_action :authenticate_user!
  
  # Economic and Revenue Analysis Reports
  def economics
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    @title = "Bid Economics Analysis"
    
    @snapshots = BidAnalyticSnapshot
                    .where(period_type: @period_type)
                    .where("period_start >= ? AND period_end <= ?", @date_range[:start], @date_range[:end])
                    .order(period_start: :desc)
    
    # Overall metrics
    @overall_metrics = calculate_overall_metrics(@snapshots)
    
    # Bid distribution data for histogram 
    @bid_amounts = Bid.where(created_at: @date_range[:start]..@date_range[:end])
                     .where.not(amount: nil)
                     .pluck(:amount)
                     .sort
    
    @response_times = Bid.where(created_at: @date_range[:start]..@date_range[:end])
                        .joins(:api_request)
                        .where.not(api_requests: { duration_ms: nil })
                        .pluck('api_requests.duration_ms')
    
    # Generate time series data for charts
    @chart_data = generate_chart_data(@snapshots)
    
    # Get top distributions by average bid amount
    @top_distributions = get_top_distributions_by_metric(:avg_amount)
    
    # Get top sources
    @top_sources = get_top_sources_by_bids
    
    # Get bid distribution by amount ranges
    @bid_ranges = calculate_bid_ranges(@bid_amounts)
    
    # Get bidding success rates
    @success_rates = calculate_success_rates(@snapshots)
    
    # Paginate snapshots for the table
    @pagy, @snapshots = pagy(@snapshots)
  end
  
  def revenue
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    @title = "Revenue Analysis"
    
    @snapshots = BidAnalyticSnapshot
                    .where(period_type: @period_type)
                    .where("period_start >= ? AND period_end <= ?", @date_range[:start], @date_range[:end])
                    .order(period_start: :desc)
    
    # Overall metrics
    @overall_metrics = calculate_overall_metrics(@snapshots)
    
    # Generate time series data for charts
    @chart_data = generate_chart_data(@snapshots)
    
    # Revenue by distribution
    @revenue_by_distribution = calculate_revenue_by_distribution(@snapshots)
    
    # Revenue by source
    @revenue_by_source = calculate_revenue_by_source(@snapshots)
    
    # Revenue by day/hour (time period analysis)
    @revenue_by_time = calculate_revenue_by_time(@snapshots, @period_type)
    
    # Revenue by lead characteristics
    @revenue_by_lead_char = calculate_revenue_by_lead_characteristics(@date_range)
    
    # Paginate snapshots for the table
    @pagy, @snapshots = pagy(@snapshots)
  end
  
  def campaign_economics
    @campaign = Campaign.find(params[:id])
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    @title = "Bid Economics for #{@campaign.name}"
    
    @snapshots = BidAnalyticSnapshot
                    .for_campaign(@campaign.id)
                    .where(period_type: @period_type)
                    .where("period_start >= ? AND period_end <= ?", @date_range[:start], @date_range[:end])
                    .order(period_start: :desc)
    
    # Overall metrics for this campaign
    @overall_metrics = calculate_overall_metrics(@snapshots)
    
    # Bid distribution data for histogram (just for this campaign)
    @bid_amounts = Bid.joins(:bid_request)
                     .where(bid_requests: { campaign_id: @campaign.id })
                     .where(created_at: @date_range[:start]..@date_range[:end])
                     .where.not(amount: nil)
                     .pluck(:amount)
                     .sort
    
    @response_times = Bid.joins(:bid_request)
                        .where(bid_requests: { campaign_id: @campaign.id })
                        .where(created_at: @date_range[:start]..@date_range[:end])
                        .joins(:api_request)
                        .where.not(api_requests: { duration_ms: nil })
                        .pluck('api_requests.duration_ms')
    
    # Generate time series data for charts
    @chart_data = generate_chart_data(@snapshots)
    
    # Get top distributions for this campaign
    @top_distributions = get_top_distributions_for_campaign(@campaign.id)
    
    # Get bid distribution by amount ranges
    @bid_ranges = calculate_bid_ranges(@bid_amounts)
    
    # Get bidding success rates
    @success_rates = calculate_success_rates(@snapshots)
    
    # Paginate snapshots for the table
    @pagy, @snapshots = pagy(@snapshots)
    
    render :economics
  end
  
  def distribution_economics
    @distribution = Distribution.find(params[:id])
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    @title = "Bid Economics for #{@distribution.name}"
    
    @snapshots = BidAnalyticSnapshot
                    .for_distribution(@distribution.id)
                    .where(period_type: @period_type)
                    .where("period_start >= ? AND period_end <= ?", @date_range[:start], @date_range[:end])
                    .order(period_start: :desc)
    
    # Overall metrics for this distribution
    @overall_metrics = calculate_overall_metrics(@snapshots)
    
    # Bid data specific to this distribution
    @bid_amounts = Bid.where(distribution_id: @distribution.id)
                     .where(created_at: @date_range[:start]..@date_range[:end])
                     .where.not(amount: nil)
                     .pluck(:amount)
                     .sort
    
    @response_times = Bid.where(distribution_id: @distribution.id)
                        .where(created_at: @date_range[:start]..@date_range[:end])
                        .joins(:api_request)
                        .where.not(api_requests: { duration_ms: nil })
                        .pluck('api_requests.duration_ms')
    
    # Generate time series data for charts
    @chart_data = generate_chart_data(@snapshots)
    
    # Get top campaigns for this distribution
    @top_campaigns = get_top_campaigns_for_distribution(@distribution.id)
    
    # Get bid distribution by amount ranges
    @bid_ranges = calculate_bid_ranges(@bid_amounts)
    
    # Get bidding success rates
    @success_rates = calculate_success_rates(@snapshots)
    
    # Paginate snapshots for the table
    @pagy, @snapshots = pagy(@snapshots)
    
    render :economics
  end
  
  def campaign_revenue
    @campaign = Campaign.find(params[:id])
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    @title = "Revenue Analysis for #{@campaign.name}"
    
    @snapshots = BidAnalyticSnapshot
                    .for_campaign(@campaign.id)
                    .where(period_type: @period_type)
                    .where("period_start >= ? AND period_end <= ?", @date_range[:start], @date_range[:end])
                    .order(period_start: :desc)
    
    # Overall metrics for this campaign
    @overall_metrics = calculate_overall_metrics(@snapshots)
    
    # Generate time series data for charts
    @chart_data = generate_chart_data(@snapshots)
    
    # Revenue by distribution for this campaign
    @revenue_by_distribution = calculate_revenue_by_distribution(@snapshots)
    
    # Revenue by source for this campaign
    @revenue_by_source = calculate_revenue_by_source(@snapshots)
    
    # Revenue by day/hour
    @revenue_by_time = calculate_revenue_by_time(@snapshots, @period_type)
    
    # Revenue by lead characteristics for this campaign
    @revenue_by_lead_char = calculate_revenue_by_lead_characteristics(@date_range, @campaign.id)
    
    # Paginate snapshots for the table
    @pagy, @snapshots = pagy(@snapshots)
    
    render :revenue
  end
  
  def distribution_revenue
    @distribution = Distribution.find(params[:id])
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    @title = "Revenue Analysis for #{@distribution.name}"
    
    @snapshots = BidAnalyticSnapshot
                    .for_distribution(@distribution.id)
                    .where(period_type: @period_type)
                    .where("period_start >= ? AND period_end <= ?", @date_range[:start], @date_range[:end])
                    .order(period_start: :desc)
    
    # Overall metrics for this distribution
    @overall_metrics = calculate_overall_metrics(@snapshots)
    
    # Generate time series data for charts
    @chart_data = generate_chart_data(@snapshots)
    
    # Revenue by campaign for this distribution
    @revenue_by_campaign = calculate_revenue_by_campaign(@snapshots)
    
    # Revenue by source for this distribution
    @revenue_by_source = calculate_revenue_by_source(@snapshots)
    
    # Revenue by day/hour
    @revenue_by_time = calculate_revenue_by_time(@snapshots, @period_type)
    
    # Revenue by lead characteristics for this distribution
    @revenue_by_lead_char = calculate_revenue_by_lead_characteristics(@date_range, nil, @distribution.id)
    
    # Paginate snapshots for the table
    @pagy, @snapshots = pagy(@snapshots)
    
    render :revenue
  end
  
  def index
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    
    @snapshots = BidAnalyticSnapshot
                      .where(period_type: @period_type)
                      .where("period_start >= ? AND period_end <= ?", @date_range[:start], @date_range[:end])
                      .order(period_start: :desc)
    
    # Overall metrics
    @overall_metrics = calculate_overall_metrics(@snapshots)
    
    # Filter by campaign if specified
    if params[:campaign_id].present?
      @campaign = Campaign.find(params[:campaign_id])
      @snapshots = @snapshots.for_campaign(@campaign.id)
      @title = "Bid Reports for #{@campaign.name}"
    else
      @title = "Bid Reports"
    end
    
    # Filter by distribution if specified
    if params[:distribution_id].present?
      @distribution = Distribution.find(params[:distribution_id])
      @snapshots = @snapshots.for_distribution(@distribution.id)
      @title = "Bid Reports for #{@distribution.name}"
    end
    
    # Paginate results
    @pagy, @snapshots = pagy(@snapshots)
    
    # Generate time series data for charts
    @chart_data = generate_chart_data(@snapshots)
    
    # Get top campaigns and distributions if viewing all account data
    if !params[:campaign_id].present? && !params[:distribution_id].present?
      @top_campaigns = get_top_campaigns
      @top_distributions = get_top_distributions
    end
    
    # Generate report on demand if requested
    if params[:generate] == 'true' && current_user.admin?
      generate_report_now
      redirect_to bid_reports_path(period_type: @period_type), notice: "Report generation started. Refresh in a few moments."
    end
  end
  
  def show
    @snapshot = BidAnalyticSnapshot.find(params[:id])
    @campaign = @snapshot.campaign
    @distribution = @snapshot.distribution
    
    # Detailed metrics
    @detailed_metrics = {
      bid_response_time: {
        value: "#{@snapshot.metrics['avg_response_time'].to_f.round(2)} seconds",
        description: "Average time between bid request and bid submission"
      },
      expiration_time: {
        value: "#{@snapshot.metrics['time_to_expiration'].to_f.round(2)} seconds",
        description: "Average time until bid request expiration"
      },
      conversion_rate: {
        value: "#{@snapshot.conversion_rate.round(2)}%",
        description: "Percentage of bids that led to conversions"
      },
      acceptance_rate: {
        value: "#{@snapshot.acceptance_rate.round(2)}%",
        description: "Percentage of bids that were accepted"
      },
      revenue_per_bid: {
        value: @snapshot.avg_revenue_per_bid,
        description: "Average revenue generated per bid"
      },
      revenue_per_accepted_bid: {
        value: @snapshot.avg_revenue_per_accepted_bid,
        description: "Average revenue generated per accepted bid"
      }
    }
    
    # Campaign-specific metrics if applicable
    if @campaign
      campaign_stats = @snapshot.metrics.dig('campaign_stats', @campaign.id.to_s) || {}
      @campaign_metrics = {
        total_bids: campaign_stats['total_bids'] || 0,
        accepted_bids: campaign_stats['accepted_bids'] || 0,
        acceptance_rate: "#{(campaign_stats['acceptance_rate'] || 0).round(2)}%",
        avg_amount: campaign_stats['avg_amount'] || 0
      }
    end
    
    # Distribution-specific metrics if applicable
    if @distribution
      distribution_stats = @snapshot.metrics.dig('distribution_stats', @distribution.id.to_s) || {}
      @distribution_metrics = {
        total_bids: distribution_stats['total_bids'] || 0,
        accepted_bids: distribution_stats['accepted_bids'] || 0,
        acceptance_rate: "#{(distribution_stats['acceptance_rate'] || 0).round(2)}%",
        avg_amount: distribution_stats['avg_amount'] || 0
      }
    end
  end
  
  def campaign
    @campaign = Campaign.find(params[:id])
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    
    @snapshots = BidAnalyticSnapshot
                      .for_campaign(@campaign.id)
                      .where(period_type: @period_type)
                      .where("period_start >= ? AND period_end <= ?", @date_range[:start], @date_range[:end])
                      .order(period_start: :desc)
    
    @pagy, @snapshots = pagy(@snapshots)
    @chart_data = generate_chart_data(@snapshots)
    
    render :index
  end
  
  def distribution
    @distribution = Distribution.find(params[:id])
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    
    @snapshots = BidAnalyticSnapshot
                      .for_distribution(@distribution.id)
                      .where(period_type: @period_type)
                      .where("period_start >= ? AND period_end <= ?", @date_range[:start], @date_range[:end])
                      .order(period_start: :desc)
    
    @pagy, @snapshots = pagy(@snapshots)
    @chart_data = generate_chart_data(@snapshots)
    
    render :index
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
  
  def calculate_overall_metrics(snapshots)
    return {} if snapshots.empty?
    
    total_bids = snapshots.sum(:total_bids)
    accepted_bids = snapshots.sum(:accepted_bids)
    avg_bid_amount = snapshots.sum { |s| s.avg_bid_amount * s.total_bids } / [total_bids, 1].max
    
    {
      total_bids: total_bids,
      accepted_bids: accepted_bids,
      acceptance_rate: total_bids > 0 ? (accepted_bids.to_f / total_bids * 100).round(2) : 0,
      avg_bid_amount: avg_bid_amount.round(2),
      total_revenue: snapshots.sum(:total_revenue).round(2),
      conversion_count: snapshots.sum(:conversion_count)
    }
  end
  
  def generate_chart_data(snapshots)
    chart_data = {
      labels: [],
      total_bids: [],
      accepted_bids: [],
      avg_bid_amount: [],
      total_revenue: []
    }
    
    snapshots.order(period_start: :asc).each do |snapshot|
      # Format label based on period type
      label = case snapshot.period_type
              when 'hourly' then snapshot.period_start.strftime("%H:%M")
              when 'daily' then snapshot.period_start.strftime("%b %d")
              when 'weekly' then "W#{snapshot.period_start.strftime('%U')}"
              when 'monthly' then snapshot.period_start.strftime("%b %Y")
              else snapshot.period_start.strftime("%b %d")
              end
      
      chart_data[:labels] << label
      chart_data[:total_bids] << snapshot.total_bids
      chart_data[:accepted_bids] << snapshot.accepted_bids
      chart_data[:avg_bid_amount] << snapshot.avg_bid_amount.to_f.round(2)
      chart_data[:total_revenue] << snapshot.total_revenue.to_f.round(2)
    end
    
    chart_data
  end
  
  def get_top_campaigns
    snapshots = BidAnalyticSnapshot
                    .where(period_type: @period_type)
                    .where("period_start >= ? AND period_end <= ?", @date_range[:start], @date_range[:end])
    
    campaign_data = {}
    
    # Process each snapshot to aggregate campaign data
    snapshots.each do |snapshot|
      snapshot.metrics.dig('campaign_stats')&.each do |campaign_id, stats|
        campaign_id = campaign_id.to_i
        campaign_data[campaign_id] ||= { total_bids: 0, accepted_bids: 0, total_amount: 0 }
        campaign_data[campaign_id][:total_bids] += stats['total_bids'].to_i
        campaign_data[campaign_id][:accepted_bids] += stats['accepted_bids'].to_i
        campaign_data[campaign_id][:total_amount] += stats['avg_amount'].to_f * stats['total_bids'].to_i
      end
    end
    
    # Calculate metrics and sort
    campaign_metrics = campaign_data.map do |campaign_id, data|
      campaign = Campaign.find_by(id: campaign_id)
      next unless campaign
      
      {
        id: campaign_id,
        name: campaign.name,
        total_bids: data[:total_bids],
        accepted_bids: data[:accepted_bids],
        acceptance_rate: data[:total_bids] > 0 ? (data[:accepted_bids].to_f / data[:total_bids] * 100).round(2) : 0,
        avg_amount: data[:total_bids] > 0 ? (data[:total_amount] / data[:total_bids]).round(2) : 0
      }
    end.compact
    
    # Sort by total bids descending and take top 5
    campaign_metrics.sort_by { |m| -m[:total_bids] }.take(5)
  end
  
  def get_top_distributions
    snapshots = BidAnalyticSnapshot
                    .where(period_type: @period_type)
                    .where("period_start >= ? AND period_end <= ?", @date_range[:start], @date_range[:end])
    
    distribution_data = {}
    
    # Process each snapshot to aggregate distribution data
    snapshots.each do |snapshot|
      snapshot.metrics.dig('distribution_stats')&.each do |distribution_id, stats|
        distribution_id = distribution_id.to_i
        distribution_data[distribution_id] ||= { total_bids: 0, accepted_bids: 0, total_amount: 0 }
        distribution_data[distribution_id][:total_bids] += stats['total_bids'].to_i
        distribution_data[distribution_id][:accepted_bids] += stats['accepted_bids'].to_i
        distribution_data[distribution_id][:total_amount] += stats['avg_amount'].to_f * stats['total_bids'].to_i
      end
    end
    
    # Calculate metrics and sort
    distribution_metrics = distribution_data.map do |distribution_id, data|
      distribution = Distribution.find_by(id: distribution_id)
      next unless distribution
      
      {
        id: distribution_id,
        name: distribution.name,
        total_bids: data[:total_bids],
        accepted_bids: data[:accepted_bids],
        acceptance_rate: data[:total_bids] > 0 ? (data[:accepted_bids].to_f / data[:total_bids] * 100).round(2) : 0,
        avg_amount: data[:total_bids] > 0 ? (data[:total_amount] / data[:total_bids]).round(2) : 0
      }
    end.compact
    
    # Sort by average amount descending and take top 5
    distribution_metrics.sort_by { |m| -m[:avg_amount] }.take(5)
  end
  
  def generate_report_now
    # Trigger immediate report generation for current period
    GenerateBidAnalyticsJob.perform_later(
      period_type: @period_type,
      for_date: Time.current,
      account_id: current_account.id,
      all_campaigns: true,
      all_distributions: true
    )
  end
  
  # Helper methods for bid economics reports
  
  def calculate_bid_ranges(bid_amounts)
    return [] if bid_amounts.blank?
    
    # Determine the range bounds
    min_bid = bid_amounts.min.to_f
    max_bid = bid_amounts.max.to_f
    
    # Create 5 evenly distributed ranges
    range_size = ((max_bid - min_bid) / 5.0).ceil
    
    # Handle case with too small range
    range_size = 1.0 if range_size.zero?
    
    ranges = []
    (0..4).each do |i|
      range_min = min_bid + (i * range_size)
      range_max = min_bid + ((i + 1) * range_size)
      
      # For the last range, ensure we include the max value
      range_max = max_bid if i == 4
      
      # Count bids in this range
      count = bid_amounts.count { |amount| amount >= range_min && amount <= range_max }
      
      ranges << {
        label: "$#{range_min.round(2)} - $#{range_max.round(2)}",
        min: range_min,
        max: range_max,
        count: count,
        percentage: bid_amounts.size > 0 ? (count.to_f / bid_amounts.size * 100).round(1) : 0
      }
    end
    
    ranges
  end
  
  def calculate_success_rates(snapshots)
    {
      acceptance_rate: snapshots.sum(:accepted_bids).to_f / [snapshots.sum(:total_bids), 1].max * 100,
      rejection_rate: snapshots.sum(:rejected_bids).to_f / [snapshots.sum(:total_bids), 1].max * 100,
      expiration_rate: snapshots.sum(:expired_bids).to_f / [snapshots.sum(:total_bids), 1].max * 100,
      conversion_rate: snapshots.sum(:conversion_count).to_f / [snapshots.sum(:accepted_bids), 1].max * 100
    }
  end
  
  def get_top_distributions_by_metric(metric = :avg_amount, limit = 5)
    snapshots = BidAnalyticSnapshot
                    .where(period_type: @period_type)
                    .where("period_start >= ? AND period_end <= ?", @date_range[:start], @date_range[:end])
    
    distribution_data = {}
    
    # Process each snapshot to aggregate distribution data
    snapshots.each do |snapshot|
      snapshot.metrics.dig('distribution_stats')&.each do |distribution_id, stats|
        distribution_id = distribution_id.to_i
        distribution_data[distribution_id] ||= { total_bids: 0, accepted_bids: 0, total_amount: 0, response_time: 0, response_count: 0 }
        distribution_data[distribution_id][:total_bids] += stats['total_bids'].to_i
        distribution_data[distribution_id][:accepted_bids] += stats['accepted_bids'].to_i
        distribution_data[distribution_id][:total_amount] += stats['avg_amount'].to_f * stats['total_bids'].to_i
        
        # Response time metrics, if available
        if stats['avg_response_time'].to_f > 0
          distribution_data[distribution_id][:response_time] += stats['avg_response_time'].to_f * stats['total_bids'].to_i
          distribution_data[distribution_id][:response_count] += stats['total_bids'].to_i
        end
      end
    end
    
    # Calculate metrics and sort
    distribution_metrics = distribution_data.map do |distribution_id, data|
      distribution = Distribution.find_by(id: distribution_id)
      next unless distribution
      
      avg_amount = data[:total_bids] > 0 ? (data[:total_amount] / data[:total_bids]).round(2) : 0
      avg_response_time = data[:response_count] > 0 ? (data[:response_time] / data[:response_count]).round(2) : 0
      acceptance_rate = data[:total_bids] > 0 ? (data[:accepted_bids].to_f / data[:total_bids] * 100).round(2) : 0
      
      {
        id: distribution_id,
        name: distribution.name,
        total_bids: data[:total_bids],
        accepted_bids: data[:accepted_bids],
        acceptance_rate: acceptance_rate,
        avg_amount: avg_amount,
        avg_response_time: avg_response_time
      }
    end.compact
    
    # Sort based on the requested metric
    case metric
    when :avg_amount
      distribution_metrics.sort_by { |m| -m[:avg_amount] }.take(limit)
    when :total_bids
      distribution_metrics.sort_by { |m| -m[:total_bids] }.take(limit)
    when :acceptance_rate
      distribution_metrics.sort_by { |m| -m[:acceptance_rate] }.take(limit)
    when :response_time
      distribution_metrics.sort_by { |m| m[:avg_response_time] }.take(limit)
    else
      distribution_metrics.sort_by { |m| -m[:avg_amount] }.take(limit)
    end
  end
  
  def get_top_sources_by_bids(limit = 5)
    # Find sources with the most bids and highest average bid amounts
    bids_by_source = BidRequest.where(created_at: @date_range[:start]..@date_range[:end])
                             .joins(:bids, :lead)
                             .where.not(bids: { amount: nil })
                             .where.not(leads: { source_id: nil })
                             .group('leads.source_id')
                             .select('leads.source_id, 
                                     COUNT(bids.id) as total_bids, 
                                     AVG(bids.amount) as avg_amount,
                                     SUM(CASE WHEN bids.status = 1 THEN 1 ELSE 0 END) as accepted_bids')
    
    source_data = bids_by_source.map do |data|
      source = Source.find_by(id: data.source_id)
      next unless source
      
      {
        id: source.id,
        name: source.name,
        total_bids: data.total_bids,
        avg_amount: data.avg_amount.to_f.round(2),
        accepted_bids: data.accepted_bids,
        acceptance_rate: data.total_bids > 0 ? (data.accepted_bids.to_f / data.total_bids * 100).round(2) : 0
      }
    end.compact
    
    source_data.sort_by { |s| -s[:total_bids] }.take(limit)
  end
  
  def get_top_distributions_for_campaign(campaign_id, limit = 5)
    # Find distributions with the highest bid amounts for a specific campaign
    bids_by_distribution = BidRequest.where(campaign_id: campaign_id)
                                   .where(created_at: @date_range[:start]..@date_range[:end])
                                   .joins(:bids)
                                   .where.not(bids: { amount: nil })
                                   .group('bids.distribution_id')
                                   .select('bids.distribution_id, 
                                           COUNT(bids.id) as total_bids, 
                                           AVG(bids.amount) as avg_amount,
                                           SUM(CASE WHEN bids.status = 1 THEN 1 ELSE 0 END) as accepted_bids')
    
    distribution_data = bids_by_distribution.map do |data|
      distribution = Distribution.find_by(id: data.distribution_id)
      next unless distribution
      
      {
        id: distribution.id,
        name: distribution.name,
        total_bids: data.total_bids,
        avg_amount: data.avg_amount.to_f.round(2),
        accepted_bids: data.accepted_bids,
        acceptance_rate: data.total_bids > 0 ? (data.accepted_bids.to_f / data.total_bids * 100).round(2) : 0
      }
    end.compact
    
    distribution_data.sort_by { |d| -d[:avg_amount] }.take(limit)
  end
  
  def get_top_campaigns_for_distribution(distribution_id, limit = 5)
    # Find campaigns with the most bids from a specific distribution
    bids_by_campaign = Bid.where(distribution_id: distribution_id)
                        .where(created_at: @date_range[:start]..@date_range[:end])
                        .joins(:bid_request)
                        .where.not(amount: nil)
                        .group('bid_requests.campaign_id')
                        .select('bid_requests.campaign_id, 
                                COUNT(bids.id) as total_bids, 
                                AVG(bids.amount) as avg_amount,
                                SUM(CASE WHEN bids.status = 1 THEN 1 ELSE 0 END) as accepted_bids')
    
    campaign_data = bids_by_campaign.map do |data|
      campaign = Campaign.find_by(id: data.campaign_id)
      next unless campaign
      
      {
        id: campaign.id,
        name: campaign.name,
        total_bids: data.total_bids,
        avg_amount: data.avg_amount.to_f.round(2),
        accepted_bids: data.accepted_bids,
        acceptance_rate: data.total_bids > 0 ? (data.accepted_bids.to_f / data.total_bids * 100).round(2) : 0
      }
    end.compact
    
    campaign_data.sort_by { |c| -c[:total_bids] }.take(limit)
  end
  
  # Helper methods for revenue analysis reports
  
  def calculate_revenue_by_distribution(snapshots)
    distribution_revenue = {}
    
    snapshots.each do |snapshot|
      snapshot.metrics.dig('distribution_stats')&.each do |distribution_id, stats|
        distribution_id = distribution_id.to_i
        revenue = stats['accepted_bids'].to_i * stats['avg_amount'].to_f
        
        distribution_revenue[distribution_id] ||= { total_revenue: 0, total_bids: 0, accepted_bids: 0 }
        distribution_revenue[distribution_id][:total_revenue] += revenue
        distribution_revenue[distribution_id][:total_bids] += stats['total_bids'].to_i
        distribution_revenue[distribution_id][:accepted_bids] += stats['accepted_bids'].to_i
      end
    end
    
    # Format the data with distribution names
    distribution_revenue.map do |distribution_id, data|
      distribution = Distribution.find_by(id: distribution_id)
      next unless distribution
      
      {
        id: distribution_id,
        name: distribution.name,
        total_revenue: data[:total_revenue].round(2),
        accepted_bids: data[:accepted_bids],
        revenue_per_accepted_bid: data[:accepted_bids] > 0 ? (data[:total_revenue] / data[:accepted_bids]).round(2) : 0,
        revenue_per_total_bid: data[:total_bids] > 0 ? (data[:total_revenue] / data[:total_bids]).round(2) : 0
      }
    end.compact.sort_by { |d| -d[:total_revenue] }
  end
  
  def calculate_revenue_by_campaign(snapshots)
    campaign_revenue = {}
    
    snapshots.each do |snapshot|
      snapshot.metrics.dig('campaign_stats')&.each do |campaign_id, stats|
        campaign_id = campaign_id.to_i
        revenue = stats['accepted_bids'].to_i * stats['avg_amount'].to_f
        
        campaign_revenue[campaign_id] ||= { total_revenue: 0, total_bids: 0, accepted_bids: 0 }
        campaign_revenue[campaign_id][:total_revenue] += revenue
        campaign_revenue[campaign_id][:total_bids] += stats['total_bids'].to_i
        campaign_revenue[campaign_id][:accepted_bids] += stats['accepted_bids'].to_i
      end
    end
    
    # Format the data with campaign names
    campaign_revenue.map do |campaign_id, data|
      campaign = Campaign.find_by(id: campaign_id)
      next unless campaign
      
      {
        id: campaign_id,
        name: campaign.name,
        total_revenue: data[:total_revenue].round(2),
        accepted_bids: data[:accepted_bids],
        revenue_per_accepted_bid: data[:accepted_bids] > 0 ? (data[:total_revenue] / data[:accepted_bids]).round(2) : 0,
        revenue_per_total_bid: data[:total_bids] > 0 ? (data[:total_revenue] / data[:total_bids]).round(2) : 0
      }
    end.compact.sort_by { |c| -c[:total_revenue] }
  end
  
  def calculate_revenue_by_source(snapshots)
    # For source revenue analysis, we need to query the database directly since
    # the snapshot metrics don't break down by source
    
    # Get all accepted bids in the date range
    accepted_bids = Bid.where(status: :accepted)
                      .where(created_at: @date_range[:start]..@date_range[:end])
                      .joins(bid_request: :lead)
                      .select('bids.id, bids.amount, leads.source_id')
    
    # Group by source
    source_revenue = {}
    accepted_bids.each do |bid|
      source_id = bid.source_id
      next unless source_id
      
      source_revenue[source_id] ||= { total_revenue: 0, bid_count: 0 }
      source_revenue[source_id][:total_revenue] += bid.amount.to_f
      source_revenue[source_id][:bid_count] += 1
    end
    
    # Format the data with source names
    source_revenue.map do |source_id, data|
      source = Source.find_by(id: source_id)
      next unless source
      
      {
        id: source_id,
        name: source.name,
        total_revenue: data[:total_revenue].round(2),
        accepted_bids: data[:bid_count],
        revenue_per_bid: data[:bid_count] > 0 ? (data[:total_revenue] / data[:bid_count]).round(2) : 0
      }
    end.compact.sort_by { |s| -s[:total_revenue] }
  end
  
  def calculate_revenue_by_time(snapshots, period_type)
    time_revenue = {}
    
    snapshots.each do |snapshot|
      # Format time key based on period type
      time_key = case period_type
                 when 'hourly'
                   snapshot.period_start.strftime("%H:00")
                 when 'daily'
                   snapshot.period_start.strftime("%a")  # Day of week
                 when 'weekly'
                   snapshot.period_start.strftime("Week %U")
                 when 'monthly'
                   snapshot.period_start.strftime("%b")  # Month name
                 end
      
      time_revenue[time_key] ||= { total_revenue: 0, accepted_bids: 0 }
      time_revenue[time_key][:total_revenue] += snapshot.total_revenue.to_f
      time_revenue[time_key][:accepted_bids] += snapshot.accepted_bids
    end
    
    # Format data for display, ensuring proper ordering
    formatted_data = time_revenue.map do |time, data|
      {
        time_period: time,
        total_revenue: data[:total_revenue].round(2),
        accepted_bids: data[:accepted_bids],
        revenue_per_bid: data[:accepted_bids] > 0 ? (data[:total_revenue] / data[:accepted_bids]).round(2) : 0
      }
    end
    
    # Order by time period appropriately
    case period_type
    when 'hourly'
      formatted_data.sort_by { |d| d[:time_period].to_i }
    when 'daily'
      # Order by day of week (Sun, Mon, Tue, etc.)
      day_order = { "Sun" => 0, "Mon" => 1, "Tue" => 2, "Wed" => 3, "Thu" => 4, "Fri" => 5, "Sat" => 6 }
      formatted_data.sort_by { |d| day_order[d[:time_period]] || 0 }
    when 'weekly', 'monthly'
      formatted_data
    end
  end
  
  def calculate_revenue_by_lead_characteristics(date_range, campaign_id = nil, distribution_id = nil)
    # This is a more complex analysis that looks at lead data characteristics
    # For simplicity, we'll implement a basic version based on a few key fields
    
    # Base query for accepted bids with lead data
    query = Bid.where(status: :accepted)
               .where(created_at: date_range[:start]..date_range[:end])
               .joins(bid_request: :lead)
    
    # Add filters if requested
    query = query.where(bid_requests: { campaign_id: campaign_id }) if campaign_id
    query = query.where(distribution_id: distribution_id) if distribution_id
    
    # For demo purposes, we'll analyze revenue by source quality/tier
    # In a real implementation, this would analyze lead data fields
    
    source_quality_revenue = {}
    
    accepted_bids = query.select('bids.amount, leads.source_id')
    
    accepted_bids.each do |bid|
      # Get the source (in a real system, we'd get actual lead fields)
      source = Source.find_by(id: bid.source_id)
      next unless source
      
      # Categorize the source (demo implementation - this would use real lead data)
      quality = case
                when source.name.include?('Premium')
                  'Premium'
                when source.name.include?('Standard')
                  'Standard'
                else
                  'Basic'
                end
      
      source_quality_revenue[quality] ||= { total_revenue: 0, bid_count: 0 }
      source_quality_revenue[quality][:total_revenue] += bid.amount.to_f
      source_quality_revenue[quality][:bid_count] += 1
    end
    
    # Format the data for display
    source_quality_revenue.map do |quality, data|
      {
        characteristic: quality,
        total_revenue: data[:total_revenue].round(2),
        accepted_bids: data[:bid_count],
        revenue_per_bid: data[:bid_count] > 0 ? (data[:total_revenue] / data[:bid_count]).round(2) : 0
      }
    end.sort_by { |d| -d[:total_revenue] }
  end
end
