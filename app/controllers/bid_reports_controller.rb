class BidReportsController < ApplicationController
  before_action :authenticate_user!
  
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
end
