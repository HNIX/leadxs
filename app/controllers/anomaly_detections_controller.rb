class AnomalyDetectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_anomaly_detection, only: [:show, :acknowledge, :resolve, :history]
  
  def index
    # Default to showing all anomalies, with filters for status, time range, and severity
    @status = params[:status] || "all" 
    @severity = params[:severity] || "all"
    @time_range = params[:time_range] || "week"
    @metric = params[:metric]
    @campaign_id = params[:campaign_id]
    @distribution_id = params[:distribution_id]
    
    # Start with all anomalies for the current account
    @anomaly_detections = AnomalyDetection.all
    
    # Apply filters
    @anomaly_detections = filter_anomalies(@anomaly_detections)
    
    # Order anomalies by detected_at, most recent first
    @anomaly_detections = @anomaly_detections.order(detected_at: :desc)
    
    # Summary metrics
    @stats = {
      total: @anomaly_detections.count,
      open: @anomaly_detections.open_anomalies.count,
      critical: @anomaly_detections.critical.count,
      resolved: @anomaly_detections.where(status: :resolved).count,
      in_last_day: @anomaly_detections.in_last_day.count
    }
    
    # Group anomalies by metric for visualization
    # Clone the relation but remove any ordering to prevent PostgreSQL grouping errors
    metric_relation = @anomaly_detections.except(:order)
    @anomalies_by_metric = metric_relation.group(:metric).count
    
    # Group anomalies by status for visualization
    status_relation = @anomaly_detections.except(:order)
    @anomalies_by_status = status_relation.group(:status).count
    
    # Paginate results
    @pagy, @anomaly_detections = pagy(@anomaly_detections)
    
    respond_to do |format|
      format.html
      format.json { render json: @anomaly_detections }
      format.csv { send_data export_anomalies_to_csv(@anomaly_detections), filename: "anomalies-#{Date.today}.csv" }
      format.xlsx { render xlsx: "export", filename: "anomalies-#{Date.today}.xlsx" }
    end
  end
  
  def dashboard
    # Get open anomalies, prioritizing critical ones
    @critical_anomalies = AnomalyDetection
                                .where(status: :open, severity: :critical)
                                .order(detected_at: :desc)
                                .limit(5)
    
    @recent_anomalies = AnomalyDetection
                              .where(status: :open)
                              .where.not(id: @critical_anomalies.pluck(:id))
                              .order(detected_at: :desc)
                              .limit(10)
    
    # Get anomaly trends over time
    @anomaly_trends = get_anomaly_trends
    
    # Get anomalies by metric type
    # Use unscoped to avoid default scopes that might include order clauses
    @anomalies_by_metric = AnomalyDetection.unscoped
                                 .where(account_id: current_tenant.id)
                                 .where(detected_at: 30.days.ago..Time.current)
                                 .group(:metric)
                                 .count
    
    # Get top anomaly sources (campaigns, distributions)
    campaign_counts = AnomalyDetection.unscoped
                        .where(account_id: current_tenant.id)
                        .where.not(campaign_id: nil)
                        .group(:campaign_id)
                        .count
    
    @top_campaign_anomalies = campaign_counts
                                .sort_by { |_id, count| -count }
                                .take(5)
                                .to_h
    
    distribution_counts = AnomalyDetection.unscoped
                            .where(account_id: current_tenant.id)
                            .where.not(distribution_id: nil)
                            .group(:distribution_id)
                            .count
    
    @top_distribution_anomalies = distribution_counts
                                    .sort_by { |_id, count| -count }
                                    .take(5)
                                    .to_h
    
    # Get anomaly resolution stats
    @resolution_stats = {
      avg_time_to_resolve: calculate_avg_resolution_time,
      resolution_rate: calculate_resolution_rate,
      repeat_anomalies: calculate_repeat_anomaly_count
    }
  end
  
  def show
    # Prepare related data for the anomaly detail view
    @threshold = @anomaly_detection.anomaly_threshold
    
    # Get historical context
    @historical_data = @anomaly_detection.context_data.dig("historical_data") || []
    
    # Get related anomalies (same metric, same entity)
    @related_anomalies = AnomalyDetection
                               .where(metric: @anomaly_detection.metric)
                               .where.not(id: @anomaly_detection.id)
                               .order(detected_at: :desc)
                               .limit(5)
    
    # Get related entity data
    if @anomaly_detection.campaign_id.present?
      @entity = @anomaly_detection.campaign
      @entity_type = "Campaign"
    elsif @anomaly_detection.distribution_id.present?
      @entity = @anomaly_detection.distribution
      @entity_type = "Distribution"
    else
      @entity = current_tenant
      @entity_type = "Account"
    end
    
    respond_to do |format|
      format.html
      format.json { render json: @anomaly_detection }
      format.pdf do
        render pdf: "anomaly-#{@anomaly_detection.id}",
               template: "anomaly_detections/export_pdf",
               layout: "pdf"
      end
    end
  end
  
  def acknowledge
    respond_to do |format|
      if @anomaly_detection.acknowledge!(current_user)
        format.html { redirect_to anomaly_detection_path(@anomaly_detection), notice: "Anomaly has been acknowledged." }
        format.json { render json: @anomaly_detection }
        format.turbo_stream { flash.now[:notice] = "Anomaly has been acknowledged." }
      else
        format.html { redirect_to anomaly_detection_path(@anomaly_detection), alert: "Could not acknowledge anomaly." }
        format.json { render json: @anomaly_detection.errors, status: :unprocessable_entity }
        format.turbo_stream { flash.now[:alert] = "Could not acknowledge anomaly." }
      end
    end
  end
  
  def resolve
    notes = params[:notes]
    
    respond_to do |format|
      if @anomaly_detection.resolve!(current_user, notes)
        format.html { redirect_to anomaly_detection_path(@anomaly_detection), notice: "Anomaly has been resolved." }
        format.json { render json: @anomaly_detection }
        format.turbo_stream { flash.now[:notice] = "Anomaly has been resolved." }
      else
        format.html { redirect_to anomaly_detection_path(@anomaly_detection), alert: "Could not resolve anomaly." }
        format.json { render json: @anomaly_detection.errors, status: :unprocessable_entity }
        format.turbo_stream { flash.now[:alert] = "Could not resolve anomaly." }
      end
    end
  end
  
  def history
    # Show history for this specific anomaly metric
    @metric = @anomaly_detection.metric
    
    # Get all past anomalies for this metric and entity
    @historical_anomalies = AnomalyDetection.unscoped
                                  .where(account_id: current_tenant.id)
                                  .where(metric: @metric)
                                  .order(detected_at: :desc)
    
    if @anomaly_detection.campaign_id.present?
      @historical_anomalies = @historical_anomalies.where(campaign_id: @anomaly_detection.campaign_id)
    elsif @anomaly_detection.distribution_id.present?
      @historical_anomalies = @historical_anomalies.where(distribution_id: @anomaly_detection.distribution_id)
    else
      @historical_anomalies = @historical_anomalies.where(campaign_id: nil, distribution_id: nil)
    end
    
    # Paginate results
    @pagy, @historical_anomalies = pagy(@historical_anomalies)
  end
  
  def run_detection
    # Run the anomaly detection service
    service = AnomalyDetectionService.new(current_tenant)
    results = service.detect_anomalies!
    
    respond_to do |format|
      if results[:errors].empty?
        format.html { redirect_to anomaly_detections_path, notice: "Anomaly detection completed. Found #{results[:detected].count} anomalies." }
        format.json { render json: results }
      else
        format.html { redirect_to anomaly_detections_path, alert: "Anomaly detection completed with errors." }
        format.json { render json: results, status: :unprocessable_entity }
      end
    end
  end
  
  def export
    @anomaly_detections = AnomalyDetection.all
    @anomaly_detections = filter_anomalies(@anomaly_detections)
    
    respond_to do |format|
      format.csv { send_data export_anomalies_to_csv(@anomaly_detections), filename: "anomalies-#{Date.today}.csv" }
      format.xlsx { render xlsx: "export", filename: "anomalies-#{Date.today}.xlsx" }
      format.pdf do
        render pdf: "anomalies-#{Date.today}",
               template: "anomaly_detections/export_pdf",
               layout: "pdf"
      end
    end
  end
  
  private
  
  def set_anomaly_detection
    @anomaly_detection = AnomalyDetection.find(params[:id])
  end
  
  def filter_anomalies(anomalies)
    # Filter by status
    if @status.present? && @status != "all"
      anomalies = anomalies.where(status: @status)
    end
    
    # Filter by severity
    if @severity.present? && @severity != "all"
      anomalies = anomalies.where(severity: @severity)
    end
    
    # Filter by time range
    case @time_range
    when "day"
      anomalies = anomalies.where(detected_at: 1.day.ago..Time.current)
    when "week"
      anomalies = anomalies.where(detected_at: 1.week.ago..Time.current)
    when "month"
      anomalies = anomalies.where(detected_at: 1.month.ago..Time.current)
    when "quarter"
      anomalies = anomalies.where(detected_at: 3.months.ago..Time.current)
    when "year"
      anomalies = anomalies.where(detected_at: 1.year.ago..Time.current)
    end
    
    # Filter by metric
    if @metric.present?
      anomalies = anomalies.where(metric: @metric)
    end
    
    # Filter by campaign
    if @campaign_id.present?
      anomalies = anomalies.where(campaign_id: @campaign_id)
    end
    
    # Filter by distribution
    if @distribution_id.present?
      anomalies = anomalies.where(distribution_id: @distribution_id)
    end
    
    anomalies
  end
  
  def export_anomalies_to_csv(anomalies)
    headers = ['ID', 'Metric', 'Value', 'Expected Value', 'Deviation %', 'Severity', 'Status', 'Detected At', 'Resolved At', 'Campaign', 'Distribution', 'Notes']
    
    CSV.generate(headers: true) do |csv|
      csv << headers
      
      anomalies.each do |anomaly|
        campaign_name = anomaly.campaign&.name || "N/A"
        distribution_name = anomaly.distribution&.name || "N/A"
        
        csv << [
          anomaly.id,
          anomaly.metric_name,
          anomaly.value,
          anomaly.expected_value,
          anomaly.deviation_percent,
          anomaly.severity,
          anomaly.status,
          anomaly.detected_at,
          anomaly.resolved_at,
          campaign_name,
          distribution_name,
          anomaly.notes
        ]
      end
    end
  end
  
  def get_anomaly_trends
    # Get count of anomalies grouped by day for the last 30 days
    # Use unscoped to avoid default scopes that might include order clauses
    anomalies_by_day = AnomalyDetection.unscoped
                             .where(account_id: current_tenant.id)
                             .where(detected_at: 30.days.ago.beginning_of_day..Time.current.end_of_day)
                             .group("DATE(detected_at)")
                             .count
    
    # Format the data for charting
    dates = (30.days.ago.to_date..Date.today).map { |date| date }
    
    {
      dates: dates.map { |d| d.strftime("%Y-%m-%d") },
      counts: dates.map { |date| anomalies_by_day[date] || 0 }
    }
  end
  
  def calculate_avg_resolution_time
    # Calculate average time to resolve anomalies (in hours)
    resolved_anomalies = AnomalyDetection.unscoped
                               .where(account_id: current_tenant.id)
                               .where(status: :resolved)
                               .where.not(resolved_at: nil)
                               .where(detected_at: 30.days.ago..Time.current)
    
    return 0 if resolved_anomalies.empty?
    
    total_hours = resolved_anomalies.sum do |anomaly|
      (anomaly.resolved_at - anomaly.detected_at) / 1.hour
    end
    
    (total_hours / resolved_anomalies.count).round(1)
  end
  
  def calculate_resolution_rate
    # Calculate percentage of anomalies that have been resolved
    total = AnomalyDetection.unscoped
                  .where(account_id: current_tenant.id)
                  .where(detected_at: 30.days.ago..Time.current)
                  .count
    
    return 0 if total == 0
    
    resolved = AnomalyDetection.unscoped
                     .where(account_id: current_tenant.id)
                     .where(status: :resolved)
                     .where(detected_at: 30.days.ago..Time.current)
                     .count
    
    ((resolved.to_f / total) * 100).round(1)
  end
  
  def calculate_repeat_anomaly_count
    # Count metrics that have had multiple anomalies
    metrics_with_anomalies = AnomalyDetection.unscoped
                                   .where(account_id: current_tenant.id)
                                   .where(detected_at: 30.days.ago..Time.current)
                                   .group(:metric)
                                   .having("COUNT(*) > 1")
                                   .count
    
    metrics_with_anomalies.count
  end
end