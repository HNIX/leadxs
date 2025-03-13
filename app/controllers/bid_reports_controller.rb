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
  
  # Compliance Performance Report
  def compliance
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    @title = "Compliance Performance Analysis"
    
    # Get compliance records for the period
    @compliance_records = ComplianceRecord
                           .where(created_at: @date_range[:start]..@date_range[:end])
                           .order(created_at: :desc)
    
    # Get consent records for the period
    @consent_records = ConsentRecord
                         .where(created_at: @date_range[:start]..@date_range[:end])
                         .order(created_at: :desc)
    
    # Calculate overall compliance metrics
    @overall_metrics = calculate_compliance_metrics(@compliance_records, @consent_records)
    
    # Consent verification rate over time
    @consent_verification_trend = calculate_consent_verification_trend(@consent_records, @period_type)
    
    # Compliance by event type
    @compliance_by_event_type = calculate_compliance_by_event_type(@compliance_records)
    
    # Compliance by action
    @compliance_by_action = calculate_compliance_by_action(@compliance_records)
    
    # Consent by type
    @consent_by_type = calculate_consent_by_type(@consent_records)
    
    # Get compliance exceptions or incidents
    @compliance_exceptions = get_compliance_exceptions(@compliance_records)
    
    # Get regulatory adherence metrics
    @regulatory_metrics = calculate_regulatory_metrics(@compliance_records, @consent_records)
    
    # Paginate compliance records for the table
    @pagy, @paginated_records = pagy(@compliance_records)
  end
  
  def campaign_compliance
    @campaign = Campaign.find(params[:id])
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    @title = "Compliance Performance for #{@campaign.name}"
    
    # Get compliance records for this campaign
    @compliance_records = ComplianceRecord
                           .where(created_at: @date_range[:start]..@date_range[:end])
                           .where(record_type: 'Campaign', record_id: @campaign.id)
                           .or(
                             ComplianceRecord
                               .where(created_at: @date_range[:start]..@date_range[:end])
                               .where(record_type: 'Lead')
                               .joins("JOIN leads ON compliance_records.record_id = leads.id::text")
                               .where(leads: { campaign_id: @campaign.id })
                           )
                           .order(created_at: :desc)
    
    # Get consent records for this campaign
    @consent_records = ConsentRecord
                         .where(created_at: @date_range[:start]..@date_range[:end])
                         .joins(:lead)
                         .where(leads: { campaign_id: @campaign.id })
                         .order(created_at: :desc)
    
    # Calculate overall compliance metrics
    @overall_metrics = calculate_compliance_metrics(@compliance_records, @consent_records)
    
    # Consent verification rate over time
    @consent_verification_trend = calculate_consent_verification_trend(@consent_records, @period_type)
    
    # Compliance by event type
    @compliance_by_event_type = calculate_compliance_by_event_type(@compliance_records)
    
    # Compliance by action
    @compliance_by_action = calculate_compliance_by_action(@compliance_records)
    
    # Consent by type
    @consent_by_type = calculate_consent_by_type(@consent_records)
    
    # Get compliance exceptions or incidents
    @compliance_exceptions = get_compliance_exceptions(@compliance_records)
    
    # Get regulatory adherence metrics
    @regulatory_metrics = calculate_regulatory_metrics(@compliance_records, @consent_records)
    
    # Paginate compliance records for the table
    @pagy, @paginated_records = pagy(@compliance_records)
    
    render :compliance
  end
  
  def distribution_compliance
    @distribution = Distribution.find(params[:id])
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    @title = "Compliance Performance for #{@distribution.name}"
    
    # Get compliance records for this distribution
    @compliance_records = ComplianceRecord
                           .where(created_at: @date_range[:start]..@date_range[:end])
                           .where(record_type: 'Distribution', record_id: @distribution.id)
                           .or(
                             ComplianceRecord
                               .where(created_at: @date_range[:start]..@date_range[:end])
                               .where(record_type: 'Lead')
                               .joins("JOIN leads ON compliance_records.record_id = leads.id::text")
                               .joins("JOIN bids ON bids.bid_request_id = leads.bid_request_id")
                               .where(bids: { distribution_id: @distribution.id, status: 1 })
                           )
                           .order(created_at: :desc)
    
    # Get consent records for this distribution
    @consent_records = ConsentRecord
                         .where(created_at: @date_range[:start]..@date_range[:end])
                         .joins(:lead)
                         .joins("JOIN bids ON bids.bid_request_id = leads.bid_request_id")
                         .where(bids: { distribution_id: @distribution.id, status: 1 })
                         .order(created_at: :desc)
    
    # Calculate overall compliance metrics
    @overall_metrics = calculate_compliance_metrics(@compliance_records, @consent_records)
    
    # Consent verification rate over time
    @consent_verification_trend = calculate_consent_verification_trend(@consent_records, @period_type)
    
    # Compliance by event type
    @compliance_by_event_type = calculate_compliance_by_event_type(@compliance_records)
    
    # Compliance by action
    @compliance_by_action = calculate_compliance_by_action(@compliance_records)
    
    # Consent by type
    @consent_by_type = calculate_consent_by_type(@consent_records)
    
    # Get compliance exceptions or incidents
    @compliance_exceptions = get_compliance_exceptions(@compliance_records)
    
    # Get regulatory adherence metrics
    @regulatory_metrics = calculate_regulatory_metrics(@compliance_records, @consent_records)
    
    # Paginate compliance records for the table
    @pagy, @paginated_records = pagy(@compliance_records)
    
    render :compliance
  end
  
  # Field-level Analysis Report
  def field_analysis
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    @title = "Field-level Performance Analysis"
    
    # Get field performance data
    @field_performance = calculate_field_performance(@date_range)
    
    # Get bid performance by field presence
    @field_presence_impact = calculate_field_presence_impact(@date_range)
    
    # Get field value distribution
    @field_value_distribution = calculate_field_value_distribution(@date_range)
    
    # Get field validation failures
    @field_validation_failures = calculate_field_validation_failures(@date_range)
    
    # Analyze completion rate by field
    @field_completion_rates = calculate_field_completion_rates(@date_range)
    
    # Get fields by bid amount impact
    @fields_by_bid_impact = get_fields_by_bid_impact(@date_range)
    
    # Get fields by acceptance rate impact
    @fields_by_acceptance_impact = get_fields_by_acceptance_impact(@date_range)
  end
  
  def campaign_field_analysis
    @campaign = Campaign.find(params[:id])
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    @title = "Field-level Analysis for #{@campaign.name}"
    
    # Get field performance data for this campaign
    @field_performance = calculate_field_performance(@date_range, @campaign.id)
    
    # Get bid performance by field presence for this campaign
    @field_presence_impact = calculate_field_presence_impact(@date_range, @campaign.id)
    
    # Get field value distribution for this campaign
    @field_value_distribution = calculate_field_value_distribution(@date_range, @campaign.id)
    
    # Get field validation failures for this campaign
    @field_validation_failures = calculate_field_validation_failures(@date_range, @campaign.id)
    
    # Analyze completion rate by field for this campaign
    @field_completion_rates = calculate_field_completion_rates(@date_range, @campaign.id)
    
    # Get fields by bid amount impact for this campaign
    @fields_by_bid_impact = get_fields_by_bid_impact(@date_range, @campaign.id)
    
    # Get fields by acceptance rate impact for this campaign
    @fields_by_acceptance_impact = get_fields_by_acceptance_impact(@date_range, @campaign.id)
    
    render :field_analysis
  end
  
  def distribution_field_analysis
    @distribution = Distribution.find(params[:id])
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    @title = "Field-level Analysis for #{@distribution.name}"
    
    # Get field performance data for this distribution
    @field_performance = calculate_field_performance(@date_range, nil, @distribution.id)
    
    # Get bid performance by field presence for this distribution
    @field_presence_impact = calculate_field_presence_impact(@date_range, nil, @distribution.id)
    
    # Get field value distribution for this distribution
    @field_value_distribution = calculate_field_value_distribution(@date_range, nil, @distribution.id)
    
    # Get field validation failures for this distribution
    @field_validation_failures = calculate_field_validation_failures(@date_range, nil, @distribution.id)
    
    # Analyze completion rate by field for this distribution
    @field_completion_rates = calculate_field_completion_rates(@date_range, nil, @distribution.id)
    
    # Get fields by bid amount impact for this distribution
    @fields_by_bid_impact = get_fields_by_bid_impact(@date_range, nil, @distribution.id)
    
    # Get fields by acceptance rate impact for this distribution
    @fields_by_acceptance_impact = get_fields_by_acceptance_impact(@date_range, nil, @distribution.id)
    
    render :field_analysis
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
  
  # Helper methods for compliance performance reports
  
  def calculate_compliance_metrics(compliance_records, consent_records)
    total_lead_count = Lead.where(created_at: @date_range[:start]..@date_range[:end]).count
    total_consent_count = consent_records.count
    # A "verified" consent is one that is not revoked and not expired (or has no expiration)
    verified_consent_count = consent_records.where(revoked: false)
                                           .where("expires_at IS NULL OR expires_at > ?", Time.current)
                                           .count
    
    verification_rate = total_consent_count > 0 ? (verified_consent_count.to_f / total_consent_count * 100).round(2) : 0
    consent_documentation_rate = total_lead_count > 0 ? (total_consent_count.to_f / total_lead_count * 100).round(2) : 0
    
    # Analyze validation failures
    validation_failures = compliance_records.where(event_type: 'validation', action: 'failed').count
    total_validations = compliance_records.where(event_type: 'validation').count
    validation_failure_rate = total_validations > 0 ? (validation_failures.to_f / total_validations * 100).round(2) : 0
    
    # Calculate incident rate
    incidents = compliance_records.where(event_type: ['consent', 'data_access'], action: ['rejected', 'unauthorized']).count
    incident_rate = compliance_records.count > 0 ? (incidents.to_f / compliance_records.count * 100).round(2) : 0
    
    # Calculate consent types
    consent_types = {
      distribution_consent: consent_records.where(consent_type: 'distribution_consent').count,
      marketing_consent: consent_records.where(consent_type: 'marketing_consent').count,
      terms_of_service: consent_records.where(consent_type: 'terms_of_service').count,
      privacy_policy: consent_records.where(consent_type: 'privacy_policy').count,
      data_sharing: consent_records.where(consent_type: 'data_sharing').count
    }
    
    # Recent consent rate trends (last 7 days vs previous 7 days)
    recent_date = @date_range[:end] - 7.days
    recent_consents = ConsentRecord.where(created_at: recent_date..@date_range[:end]).count
    previous_consents = ConsentRecord.where(created_at: (recent_date - 7.days)..recent_date).count
    consent_trend = previous_consents > 0 ? ((recent_consents - previous_consents).to_f / previous_consents * 100).round(2) : 0
    
    {
      total_leads: total_lead_count,
      total_consent_records: total_consent_count,
      verified_consent_records: verified_consent_count,
      verification_rate: verification_rate,
      consent_documentation_rate: consent_documentation_rate,
      validation_failure_rate: validation_failure_rate,
      incident_rate: incident_rate,
      consent_types: consent_types,
      consent_trend: consent_trend
    }
  end
  
  def calculate_consent_verification_trend(consent_records, period_type)
    # Group consent records by time period using standard Rails methods
    # First, convert to an array to work with the data in memory
    all_records = consent_records.to_a
    
    # Initialize a hash to store grouped records
    data = {}
    
    # Group by appropriate time period
    all_records.each do |record|
      date = record.created_at
      
      case period_type
      when 'hourly'
        # Group by hour - truncate to the hour
        period_key = Time.new(date.year, date.month, date.day, date.hour, 0, 0)
      when 'weekly'
        # Group by week - find the beginning of the week (assuming Monday as start of week)
        period_key = date.beginning_of_week
      when 'monthly'
        # Group by month - first day of the month
        period_key = date.beginning_of_month
      else
        # Default to daily - truncate to day
        period_key = date.beginning_of_day
      end
      
      # Initialize the array for this period if needed
      data[period_key] ||= []
      # Add the record to the appropriate period
      data[period_key] << record
    end
    
    # Sort by date (keys are Time objects which sort chronologically)
    data = data.sort.to_h
    
    # Calculate verification rate for each period
    trend_data = []
    
    data.each do |date, records|
      verified_count = records.count { |r| r.active? }  # Use the active? method to check if record is valid
      verification_rate = records.size > 0 ? (verified_count.to_f / records.size * 100).round(2) : 0
      
      trend_data << {
        period: date,
        verification_rate: verification_rate,
        total_records: records.size,
        verified_records: verified_count,
        formatted_date: format_date_by_period_type(date, period_type)
      }
    end
    
    trend_data
  end
  
  def calculate_compliance_by_event_type(compliance_records)
    event_types = {}
    
    # Get the total count first
    total_count = compliance_records.count
    
    # Use a simpler query to avoid PostgreSQL grouping issues - clone the relation to avoid modifying the original
    records_clone = compliance_records.except(:order)
    records_clone.select(:event_type).distinct.pluck(:event_type).each do |event_type|
      # Count records with this event type
      count = compliance_records.where(event_type: event_type).count
      
      event_types[event_type] = {
        count: count,
        percentage: total_count > 0 ? (count.to_f / total_count * 100).round(2) : 0
      }
    end
    
    event_types
  end
  
  def calculate_compliance_by_action(compliance_records)
    actions = {}
    
    # Get the total count first
    total_count = compliance_records.count
    
    # Use a simpler query to avoid PostgreSQL grouping issues - clone the relation to avoid modifying the original
    records_clone = compliance_records.except(:order)
    records_clone.select(:action).distinct.pluck(:action).each do |action|
      # Count records with this action
      count = compliance_records.where(action: action).count
      
      actions[action] = {
        count: count,
        percentage: total_count > 0 ? (count.to_f / total_count * 100).round(2) : 0
      }
    end
    
    actions
  end
  
  def calculate_consent_by_type(consent_records)
    types = {}
    
    # Get the total count first
    total_count = consent_records.count
    
    # Use a simpler query to avoid PostgreSQL grouping issues - clone the relation to avoid modifying the original
    records_clone = consent_records.except(:order)
    records_clone.select(:consent_type).distinct.pluck(:consent_type).each do |type|
      # Count records with this consent type
      count = consent_records.where(consent_type: type).count
      
      # Count verified records of this type
      verified_count = consent_records.where(consent_type: type, revoked: false)
                                    .where("expires_at IS NULL OR expires_at > ?", Time.current)
                                    .count
      
      types[type] = {
        count: count,
        percentage: total_count > 0 ? (count.to_f / total_count * 100).round(2) : 0,
        verified_count: verified_count
      }
      
      types[type][:verification_rate] = types[type][:count] > 0 ? 
                                       (types[type][:verified_count].to_f / types[type][:count] * 100).round(2) : 0
    end
    
    types
  end
  
  def get_compliance_exceptions(compliance_records)
    # Get incidents, violations, and other exceptions
    exceptions = compliance_records.where(
      event_type: ['consent', 'data_access', 'validation', 'distribution'],
      action: ['rejected', 'unauthorized', 'failed', 'error']
    ).order(created_at: :desc).limit(20)
    
    exceptions.map do |record|
      {
        id: record.id,
        event_type: record.event_type,
        action: record.action,
        record_type: record.record_type,
        record_id: record.record_id,
        created_at: record.created_at,
        user_id: record.user_id,
        user_name: record.user_id ? User.find_by(id: record.user_id)&.name : 'System',
        ip_address: record.ip_address,
        metadata: record.data
      }
    end
  end
  
  def calculate_regulatory_metrics(compliance_records, consent_records)
    # Calculate metrics specifically for regulatory requirements
    
    # 1. Calculate TCPA consent metrics (example)
    tcpa_consents = consent_records.where("metadata->>'regulatory_type' = 'TCPA'").count
    verified_tcpa_consents = consent_records.where("metadata->>'regulatory_type' = 'TCPA'")
                                          .where(revoked: false)
                                          .where("expires_at IS NULL OR expires_at > ?", Time.current)
                                          .count
    tcpa_compliance_rate = tcpa_consents > 0 ? (verified_tcpa_consents.to_f / tcpa_consents * 100).round(2) : 0
    
    # 2. Calculate PII protection metrics
    pii_access_attempts = compliance_records.where(event_type: 'data_access').where("data->>'contains_pii' = 'true'").count
    pii_unauthorized_access = compliance_records.where(event_type: 'data_access')
                                              .where(action: 'unauthorized')
                                              .where("data->>'contains_pii' = 'true'").count
    pii_protection_rate = pii_access_attempts > 0 ? 
                           ((pii_access_attempts - pii_unauthorized_access).to_f / pii_access_attempts * 100).round(2) : 100
    
    # 3. Calculate 1:1 consent metrics
    direct_consents = consent_records.where("metadata->>'direct_consent' = 'true'").count
    direct_consent_rate = consent_records.count > 0 ? (direct_consents.to_f / consent_records.count * 100).round(2) : 0
    
    # 4. Calculate opt-out handling metrics
    opt_out_requests = compliance_records.where(event_type: 'consent', action: 'revoked').count
    successful_opt_outs = compliance_records.where(event_type: 'consent')
                                          .where(action: 'revoked')
                                          .where("data->>'success' = 'true'").count
    opt_out_success_rate = opt_out_requests > 0 ? (successful_opt_outs.to_f / opt_out_requests * 100).round(2) : 100
    
    # 5. Calculate documentation completeness metrics
    required_fields_count = 5  # For example, assuming 5 fields are required for complete documentation
    docs_with_all_required = consent_records.where(
      "metadata->>'phone' IS NOT NULL AND " +
      "metadata->>'email' IS NOT NULL AND " +
      "metadata->>'timestamp' IS NOT NULL AND " +
      "metadata->>'ip_address' IS NOT NULL AND " +
      "metadata->>'user_agent' IS NOT NULL"
    ).count
    documentation_completeness = consent_records.count > 0 ? 
                                 (docs_with_all_required.to_f / consent_records.count * 100).round(2) : 0
    
    {
      tcpa_compliance_rate: tcpa_compliance_rate,
      pii_protection_rate: pii_protection_rate,
      direct_consent_rate: direct_consent_rate,
      opt_out_success_rate: opt_out_success_rate,
      documentation_completeness: documentation_completeness,
      tcpa_consents: tcpa_consents,
      verified_tcpa_consents: verified_tcpa_consents,
      pii_access_attempts: pii_access_attempts,
      pii_unauthorized_access: pii_unauthorized_access,
      direct_consents: direct_consents,
      opt_out_requests: opt_out_requests,
      successful_opt_outs: successful_opt_outs,
      docs_with_all_required: docs_with_all_required
    }
  end
  
  def format_date_by_period_type(date, period_type)
    case period_type
    when 'hourly'
      date.strftime("%H:%M")
    when 'daily'
      date.strftime("%b %d")
    when 'weekly'
      "Week #{date.strftime('%U')}"
    when 'monthly'
      date.strftime("%b %Y")
    else
      date.strftime("%b %d")
    end
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
  
  # Helper methods for field-level analysis reports
  
  def calculate_field_performance(date_range, campaign_id = nil, distribution_id = nil)
    # Get leads in the date range
    leads_query = Lead.where(created_at: date_range[:start]..date_range[:end])
    leads_query = leads_query.where(campaign_id: campaign_id) if campaign_id
    
    # If distribution is provided, we need to filter by bids
    if distribution_id
      leads_query = leads_query.joins(:bid_request => :bids)
                              .where(bid_requests: {bids: {distribution_id: distribution_id, status: 1}})
                              .distinct
    end
    
    # Get all campaign fields
    campaign_field_ids = if campaign_id
                          CampaignField.where(campaign_id: campaign_id).pluck(:id)
                        else
                          campaign_ids = leads_query.pluck(:campaign_id).uniq
                          CampaignField.where(campaign_id: campaign_ids).pluck(:id)
                        end
    
    # Get lead data for these campaigns
    lead_data = LeadData.joins(:lead)
                      .where(leads: {id: leads_query.select(:id)})
                      .where(campaign_field_id: campaign_field_ids)
    
    # Group by field
    field_data = {}
    
    lead_data.each do |data|
      field = CampaignField.find_by(id: data.campaign_field_id)
      next unless field
      
      field_data[field.id] ||= {
        field_id: field.id,
        field_name: field.name,
        data_type: field.data_type,
        pii: field.pii,
        bid_visible: field.share_during_bidding,
        required: field.required,
        completion_count: 0,
        total_count: 0,
        values: [],
        value_distribution: {}
      }
      
      field_data[field.id][:total_count] += 1
      field_data[field.id][:completion_count] += 1 if data.value.present?
      field_data[field.id][:values] << data.value if data.value.present?
      
      # Track value distribution
      if data.value.present?
        normalized_value = normalize_field_value(data.value, field.data_type)
        field_data[field.id][:value_distribution][normalized_value] ||= 0
        field_data[field.id][:value_distribution][normalized_value] += 1
      end
    end
    
    # Calculate completion rates and other metrics
    field_data.each do |field_id, data|
      data[:completion_rate] = data[:total_count] > 0 ? (data[:completion_count].to_f / data[:total_count] * 100).round(2) : 0
      
      # Calculate most common values
      data[:most_common_values] = data[:value_distribution].sort_by { |_, count| -count }.take(5).map do |value, count|
        {
          value: value,
          count: count,
          percentage: data[:completion_count] > 0 ? (count.to_f / data[:completion_count] * 100).round(2) : 0
        }
      end
      
      # Clean up raw values array that we don't need anymore
      data.delete(:values)
    end
    
    field_data.values
  end
  
  def calculate_field_presence_impact(date_range, campaign_id = nil, distribution_id = nil)
    # This analysis shows how field presence/absence impacts bid performance
    # For all fields shared during bidding, we analyze how bid amounts differ when field is present vs absent
    
    # Get relevant campaign fields that are shared during bidding
    query = CampaignField.where(share_during_bidding: true)
    query = query.where(campaign_id: campaign_id) if campaign_id
    bidding_fields = query.to_a
    
    # Return early if no fields are shared during bidding
    return [] if bidding_fields.empty?
    
    # Get all relevant bid requests
    bid_request_query = BidRequest.where(created_at: date_range[:start]..date_range[:end])
    bid_request_query = bid_request_query.where(campaign_id: campaign_id) if campaign_id
    
    # Analysis results
    field_impact = {}
    
    # For each bidding field
    bidding_fields.each do |field|
      # Get bid requests where this field had data
      field_lead_data = LeadData.joins(:lead)
                                .where(leads: { bid_request_id: bid_request_query.select(:id) })
                                .where(campaign_field_id: field.id)
                                .where.not(value: [nil, ""])
      
      lead_ids_with_field = field_lead_data.pluck('leads.id')
      
      # Get bids for leads with this field filled vs not filled
      bids_query = Bid.joins(bid_request: :lead)
                      .where(bid_requests: { id: bid_request_query.select(:id) })
                      .where.not(amount: nil)
      
      if distribution_id
        bids_query = bids_query.where(distribution_id: distribution_id)
      end
      
      # Bids with field present
      bids_with_field = bids_query.where(bid_requests: { leads: { id: lead_ids_with_field } })
      
      # All other bids
      bids_without_field = bids_query.where.not(bid_requests: { leads: { id: lead_ids_with_field } })
      
      # Calculate metrics
      with_count = bids_with_field.count
      without_count = bids_without_field.count
      
      # Only include fields with enough data
      next unless with_count > 0 && without_count > 0
      
      with_avg = bids_with_field.average(:amount).to_f.round(2)
      without_avg = bids_without_field.average(:amount).to_f.round(2)
      
      with_accepted = bids_with_field.where(status: 1).count
      without_accepted = bids_without_field.where(status: 1).count
      
      with_acceptance_rate = with_count > 0 ? (with_accepted.to_f / with_count * 100).round(2) : 0
      without_acceptance_rate = without_count > 0 ? (without_accepted.to_f / without_count * 100).round(2) : 0
      
      # Impact on bid amount
      amount_impact_percentage = without_avg > 0 ? ((with_avg - without_avg) / without_avg * 100).round(2) : 0
      
      # Impact on acceptance rate 
      acceptance_impact = without_acceptance_rate > 0 ? ((with_acceptance_rate - without_acceptance_rate) / without_acceptance_rate * 100).round(2) : 0
      
      field_impact[field.id] = {
        field_id: field.id,
        field_name: field.name,
        data_type: field.data_type,
        with_field_count: with_count,
        without_field_count: without_count,
        with_field_avg_bid: with_avg,
        without_field_avg_bid: without_avg,
        amount_impact_percentage: amount_impact_percentage,
        with_field_acceptance_rate: with_acceptance_rate,
        without_field_acceptance_rate: without_acceptance_rate,
        acceptance_impact_percentage: acceptance_impact,
        significant: (with_count > 10 && without_count > 10 && (amount_impact_percentage.abs > 5 || acceptance_impact.abs > 5))
      }
    end
    
    # Sort by impact significance
    field_impact.values.sort_by { |impact| -([impact[:amount_impact_percentage].abs, impact[:acceptance_impact_percentage].abs].max) }
  end
  
  def calculate_field_value_distribution(date_range, campaign_id = nil, distribution_id = nil)
    # Get relevant bid data
    bid_query = Bid.where(created_at: date_range[:start]..date_range[:end])
                 .where.not(amount: nil)
    
    if campaign_id
      bid_query = bid_query.joins(:bid_request).where(bid_requests: { campaign_id: campaign_id })
    end
    
    if distribution_id
      bid_query = bid_query.where(distribution_id: distribution_id)
    end
    
    # Get the top fields with the most significant variation in bid amounts
    fields_with_variation = []
    
    # Select a few important fields to analyze (could be made dynamic based on campaign)
    if campaign_id
      fields = CampaignField.where(campaign_id: campaign_id)
                            .where(share_during_bidding: true)
                            .limit(5)
    else
      # Without a specific campaign, pick some common fields that are likely to exist 
      fields = CampaignField.where(share_during_bidding: true)
                            .where(name: ['state', 'zip', 'email', 'phone', 'age'])
                            .limit(5)
    end
    
    fields.each do |field|
      # Get distinct values for this field
      lead_data = LeadData.joins(lead: {bid_request: :bids})
                         .where(bids: { id: bid_query.select(:id) })
                         .where(campaign_field_id: field.id)
                         .where.not(value: [nil, ""])
      
      # Create a clone without any ordering to avoid PostgreSQL issues with DISTINCT
      lead_data_clone = lead_data.except(:order)
      unique_values = lead_data_clone.select(:value).distinct.limit(10).pluck(:value)
      
      next if unique_values.size <= 1 # Skip if not enough distinct values
      
      value_metrics = {}
      
      # For each value, calculate bid metrics
      unique_values.each do |value|
        # Find bids for leads with this field value
        value_bids = bid_query.joins(bid_request: :lead)
                            .joins("JOIN lead_data ON lead_data.lead_id = leads.id")
                            .where("lead_data.campaign_field_id = ? AND lead_data.value = ?", field.id, value)
        
        # Get metrics for this value
        bid_count = value_bids.count
        avg_amount = value_bids.average(:amount).to_f.round(2)
        acceptance_count = value_bids.where(status: 1).count
        acceptance_rate = bid_count > 0 ? (acceptance_count.to_f / bid_count * 100).round(2) : 0
        
        # Only add if we have meaningful data
        next if bid_count < 5
        
        value_metrics[value] = {
          value: value,
          bid_count: bid_count,
          avg_amount: avg_amount,
          acceptance_rate: acceptance_rate
        }
      end
      
      # Only include fields with at least 2 values with data
      next if value_metrics.size < 2
      
      # Calculate value variance
      avg_amounts = value_metrics.values.map { |m| m[:avg_amount] }
      avg_acceptance = value_metrics.values.map { |m| m[:acceptance_rate] }
      
      # Calculate the range (max-min) as a measure of variation
      amount_range = avg_amounts.max - avg_amounts.min
      acceptance_range = avg_acceptance.max - avg_acceptance.min
      
      fields_with_variation << {
        field_id: field.id,
        field_name: field.name,
        amount_variance: amount_range,
        acceptance_variance: acceptance_range,
        value_metrics: value_metrics.values.sort_by { |m| -m[:avg_amount] }
      }
    end
    
    # Sort by amount variance
    fields_with_variation.sort_by { |f| -f[:amount_variance] }
  end
  
  def calculate_field_validation_failures(date_range, campaign_id = nil, distribution_id = nil)
    # Get validation failures from compliance records
    validation_records = ComplianceRecord.where(
                            created_at: date_range[:start]..date_range[:end],
                            event_type: 'validation'
                          )
    
    # Filter by campaign if needed
    if campaign_id
      # Direct campaign validation failures
      validation_records = validation_records.where(
                              record_type: 'Campaign',
                              record_id: campaign_id.to_s
                            ).or(
                              validation_records.where(
                                record_type: 'Lead'
                              ).joins("JOIN leads ON leads.id::text = compliance_records.record_id")
                              .where(leads: { campaign_id: campaign_id })
                            )
    end
    
    # Filter by distribution if needed (can only filter leads)
    if distribution_id
      validation_records = validation_records.where(
                              record_type: 'Lead'
                            ).joins("JOIN leads ON leads.id::text = compliance_records.record_id")
                            .joins("JOIN bids ON bids.bid_request_id = leads.bid_request_id")
                            .where(bids: { distribution_id: distribution_id, status: 1 })
    end
    
    # Group validation failures by field
    field_failures = {}
    
    validation_records.each do |record|
      # Skip if no field information in the data
      next unless record.data && record.data['field_id'].present?
      
      field_id = record.data['field_id'].to_i
      
      # Find the field
      field = CampaignField.find_by(id: field_id)
      next unless field
      
      field_failures[field_id] ||= {
        field_id: field_id,
        field_name: field.name,
        data_type: field.data_type,
        total_failures: 0,
        failure_types: {},
        failure_examples: []
      }
      
      field_failures[field_id][:total_failures] += 1
      
      # Track failure types
      failure_type = record.data['failure_type'] || 'unknown'
      field_failures[field_id][:failure_types][failure_type] ||= 0
      field_failures[field_id][:failure_types][failure_type] += 1
      
      # Keep some examples
      if field_failures[field_id][:failure_examples].size < 5 && record.data['value'].present?
        field_failures[field_id][:failure_examples] << {
          value: record.data['value'],
          message: record.data['message'] || failure_type,
          timestamp: record.created_at
        }
      end
    end
    
    # Format the data for display
    field_failures.values.each do |field|
      # Calculate most common failure types
      field[:common_failures] = field[:failure_types].sort_by { |_, count| -count }.map do |type, count|
        {
          type: type,
          count: count,
          percentage: (count.to_f / field[:total_failures] * 100).round(2)
        }
      end
    end
    
    # Sort by total failures
    field_failures.values.sort_by { |f| -f[:total_failures] }
  end
  
  def calculate_field_completion_rates(date_range, campaign_id = nil, distribution_id = nil)
    # Get leads in the date range
    leads_query = Lead.where(created_at: date_range[:start]..date_range[:end])
    
    # Apply campaign filter if needed
    leads_query = leads_query.where(campaign_id: campaign_id) if campaign_id
    
    # Apply distribution filter if needed
    if distribution_id
      leads_query = leads_query.joins(:bid_request => :bids)
                               .where(bid_requests: {bids: {distribution_id: distribution_id, status: 1}})
                               .distinct
    end
    
    # Get all campaign fields
    campaign_field_ids = if campaign_id
                           CampaignField.where(campaign_id: campaign_id).pluck(:id)
                         else
                           campaign_ids = leads_query.pluck(:campaign_id).uniq
                           CampaignField.where(campaign_id: campaign_ids).pluck(:id)
                         end
    
    # Calculate completion rates for each field
    completion_rates = {}
    
    campaign_field_ids.each do |field_id|
      field = CampaignField.find_by(id: field_id)
      next unless field
      
      # Count leads with this field
      lead_count = leads_query.count
      
      # Count leads with this field filled
      filled_count = LeadData.joins(:lead)
                             .where(leads: { id: leads_query.select(:id) })
                             .where(campaign_field_id: field_id)
                             .where.not(value: [nil, ""])
                             .count('DISTINCT leads.id')
      
      completion_rate = lead_count > 0 ? (filled_count.to_f / lead_count * 100).round(2) : 0
      
      # Only include fields that appear in at least some leads
      next if lead_count == 0
      
      completion_rates[field_id] = {
        field_id: field_id,
        field_name: field.name,
        data_type: field.data_type,
        required: field.required,
        lead_count: lead_count,
        filled_count: filled_count,
        completion_rate: completion_rate,
        is_pii: field.pii,
        shared_during_bidding: field.share_during_bidding
      }
    end
    
    # Sort by completion rate (lowest first, as these are potential issues)
    completion_rates.values.sort_by { |r| r[:completion_rate] }
  end
  
  def get_fields_by_bid_impact(date_range, campaign_id = nil, distribution_id = nil)
    # Get leads in the date range
    bid_query = Bid.where(created_at: date_range[:start]..date_range[:end])
                 .where.not(amount: nil)
    
    # Apply campaign filter if needed
    bid_query = bid_query.joins(:bid_request).where(bid_requests: { campaign_id: campaign_id }) if campaign_id
    
    # Apply distribution filter if needed
    bid_query = bid_query.where(distribution_id: distribution_id) if distribution_id
    
    # Get all relevant campaign fields 
    if campaign_id
      campaign_fields = CampaignField.where(campaign_id: campaign_id)
                                    .where(share_during_bidding: true)
    else
      campaign_ids = bid_query.joins(:bid_request).select('DISTINCT bid_requests.campaign_id').pluck('bid_requests.campaign_id')
      campaign_fields = CampaignField.where(campaign_id: campaign_ids)
                                    .where(share_during_bidding: true)
    end
    
    # Calculate impact for each field
    field_impacts = {}
    
    campaign_fields.each do |field|
      # Get all leads with this field
      leads_with_field = LeadData.joins(:lead)
                                 .where.not(value: [nil, ""])
                                 .where(campaign_field_id: field.id)
                                 .pluck('leads.id')
      
      # Skip if no leads have this field
      next if leads_with_field.empty?
      
      # Get bids for leads with this field filled 
      bids_with_field = bid_query.joins(bid_request: :lead)
                                 .where(bid_requests: { leads: { id: leads_with_field } })
      
      # Get bids for leads without this field filled
      bids_without_field = bid_query.joins(bid_request: :lead)
                                   .where.not(bid_requests: { leads: { id: leads_with_field } })
      
      # Skip if not enough data
      next if bids_with_field.count < 10 || bids_without_field.count < 10
      
      # Calculate bid amount impact
      with_avg = bids_with_field.average(:amount).to_f
      without_avg = bids_without_field.average(:amount).to_f
      
      # Calculate impact percentage
      impact_percentage = without_avg > 0 ? ((with_avg - without_avg) / without_avg * 100).round(2) : 0
      
      field_impacts[field.id] = {
        field_id: field.id,
        field_name: field.name,
        data_type: field.data_type,
        with_avg_amount: with_avg.round(2),
        without_avg_amount: without_avg.round(2),
        impact_percentage: impact_percentage,
        significant: impact_percentage.abs > 5,
        with_count: bids_with_field.count,
        without_count: bids_without_field.count
      }
    end
    
    # Sort by absolute impact percentage (highest first)
    field_impacts.values.sort_by { |impact| -impact[:impact_percentage].abs }
  end
  
  def get_fields_by_acceptance_impact(date_range, campaign_id = nil, distribution_id = nil)
    # Get bids in the date range
    bid_query = Bid.where(created_at: date_range[:start]..date_range[:end])
    
    # Apply campaign filter if needed
    bid_query = bid_query.joins(:bid_request).where(bid_requests: { campaign_id: campaign_id }) if campaign_id
    
    # Apply distribution filter if needed
    bid_query = bid_query.where(distribution_id: distribution_id) if distribution_id
    
    # Get all relevant campaign fields 
    if campaign_id
      campaign_fields = CampaignField.where(campaign_id: campaign_id)
                                    .where(share_during_bidding: true)
    else
      campaign_ids = bid_query.joins(:bid_request).select('DISTINCT bid_requests.campaign_id').pluck('bid_requests.campaign_id')
      campaign_fields = CampaignField.where(campaign_id: campaign_ids)
                                    .where(share_during_bidding: true)
    end
    
    # Calculate impact for each field
    field_impacts = {}
    
    campaign_fields.each do |field|
      # Get all leads with this field
      leads_with_field = LeadData.joins(:lead)
                                 .where.not(value: [nil, ""])
                                 .where(campaign_field_id: field.id)
                                 .pluck('leads.id')
      
      # Skip if no leads have this field
      next if leads_with_field.empty?
      
      # Get bids for leads with this field filled 
      bids_with_field = bid_query.joins(bid_request: :lead)
                                 .where(bid_requests: { leads: { id: leads_with_field } })
      
      # Get bids for leads without this field filled
      bids_without_field = bid_query.joins(bid_request: :lead)
                                   .where.not(bid_requests: { leads: { id: leads_with_field } })
      
      # Skip if not enough data
      next if bids_with_field.count < 10 || bids_without_field.count < 10
      
      # Calculate acceptance impact
      with_accepted = bids_with_field.where(status: 1).count
      without_accepted = bids_without_field.where(status: 1).count
      
      with_acceptance_rate = bids_with_field.count > 0 ? (with_accepted.to_f / bids_with_field.count * 100).round(2) : 0
      without_acceptance_rate = bids_without_field.count > 0 ? (without_accepted.to_f / bids_without_field.count * 100).round(2) : 0
      
      # Calculate impact percentage
      impact_percentage = without_acceptance_rate > 0 ? 
                          ((with_acceptance_rate - without_acceptance_rate) / without_acceptance_rate * 100).round(2) : 0
      
      field_impacts[field.id] = {
        field_id: field.id,
        field_name: field.name,
        data_type: field.data_type,
        with_acceptance_rate: with_acceptance_rate,
        without_acceptance_rate: without_acceptance_rate,
        impact_percentage: impact_percentage,
        significant: impact_percentage.abs > 10,
        with_count: bids_with_field.count,
        without_count: bids_without_field.count
      }
    end
    
    # Sort by absolute impact percentage (highest first)
    field_impacts.values.sort_by { |impact| -impact[:impact_percentage].abs }
  end
  
  def normalize_field_value(value, data_type)
    return value unless value.present?
    
    case data_type
    when 'date'
      date = value.is_a?(Date) ? value : Date.parse(value.to_s) rescue nil
      date&.strftime("%Y-%m-%d") || value
    when 'email'
      value.to_s.downcase.strip
    when 'phone'
      value.to_s.gsub(/\D/, '')  # Remove non-digits
    when 'boolean'
      value.to_s.downcase == 'true' || value.to_s == '1' ? 'true' : 'false'
    when 'number'
      value.to_s.to_f.to_s  # Normalize number format
    else
      value.to_s
    end
  end
end
