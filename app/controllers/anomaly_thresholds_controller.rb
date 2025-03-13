class AnomalyThresholdsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_anomaly_threshold, only: [:show, :edit, :update, :destroy, :toggle_status, :test]
  
  def index
    @scope = params[:scope] || "all"
    @campaign_id = params[:campaign_id]
    @distribution_id = params[:distribution_id]
    @active_only = params[:active_only] == "true"
    
    # Start with all thresholds for the current account
    @anomaly_thresholds = AnomalyThreshold.all
    
    # Apply filters
    @anomaly_thresholds = filter_thresholds(@anomaly_thresholds)
    
    # Group thresholds by metric for the view
    @thresholds_by_metric = @anomaly_thresholds.group_by(&:metric)
    
    # Get stats about thresholds
    @stats = {
      total: @anomaly_thresholds.count,
      active: @anomaly_thresholds.where(active: true).count,
      global: @anomaly_thresholds.where(campaign_id: nil, distribution_id: nil).count,
      campaign_specific: @anomaly_thresholds.where.not(campaign_id: nil).count,
      distribution_specific: @anomaly_thresholds.where.not(distribution_id: nil).count
    }
    
    respond_to do |format|
      format.html
      format.json { render json: @anomaly_thresholds }
      format.csv { send_data export_thresholds_to_csv(@anomaly_thresholds), filename: "anomaly-thresholds-#{Date.today}.csv" }
    end
  end
  
  def show
    # Get recent anomalies detected by this threshold
    @recent_anomalies = @anomaly_threshold.anomaly_detections
                                        .order(detected_at: :desc)
                                        .limit(10)
    
    # Get stats about this threshold
    @stats = {
      total_detections: @anomaly_threshold.anomaly_detections.count,
      open_detections: @anomaly_threshold.anomaly_detections.open_anomalies.count,
      last_detection: @anomaly_threshold.anomaly_detections.order(detected_at: :desc).first&.detected_at
    }
    
    # Get current metric value
    service = AnomalyDetectionService.new(current_tenant)
    @current_value = service.get_current_metric_value(@anomaly_threshold)
    @expected_value = service.get_expected_value(@anomaly_threshold)
    
    respond_to do |format|
      format.html
      format.json { render json: @anomaly_threshold }
    end
  end
  
  def new
    @anomaly_threshold = AnomalyThreshold.new
    
    # Preselect campaign or distribution if provided in params
    @anomaly_threshold.campaign_id = params[:campaign_id] if params[:campaign_id].present?
    @anomaly_threshold.distribution_id = params[:distribution_id] if params[:distribution_id].present?
    
    # Get available metrics for dropdown
    @available_metrics = AnomalyThreshold.available_metrics
    
    # Initialize metadata hash
    @anomaly_threshold.metadata = { direction: "above" }
  end
  
  def create
    @anomaly_threshold = AnomalyThreshold.new(anomaly_threshold_params)
    
    respond_to do |format|
      if @anomaly_threshold.save
        format.html { redirect_to anomaly_threshold_path(@anomaly_threshold), notice: "Anomaly threshold was successfully created." }
        format.json { render json: @anomaly_threshold, status: :created }
        format.turbo_stream { flash.now[:notice] = "Anomaly threshold was successfully created." }
      else
        @available_metrics = AnomalyThreshold.available_metrics
        format.html { render :new }
        format.json { render json: @anomaly_threshold.errors, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end
  
  def edit
    # Get available metrics for dropdown
    @available_metrics = AnomalyThreshold.available_metrics
  end
  
  def update
    respond_to do |format|
      if @anomaly_threshold.update(anomaly_threshold_params)
        format.html { redirect_to anomaly_threshold_path(@anomaly_threshold), notice: "Anomaly threshold was successfully updated." }
        format.json { render json: @anomaly_threshold }
        format.turbo_stream { flash.now[:notice] = "Anomaly threshold was successfully updated." }
      else
        @available_metrics = AnomalyThreshold.available_metrics
        format.html { render :edit }
        format.json { render json: @anomaly_threshold.errors, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end
  
  def destroy
    @anomaly_threshold.destroy
    
    respond_to do |format|
      format.html { redirect_to anomaly_thresholds_path, notice: "Anomaly threshold was successfully deleted." }
      format.json { head :no_content }
      format.turbo_stream { flash.now[:notice] = "Anomaly threshold was successfully deleted." }
    end
  end
  
  def toggle_status
    @anomaly_threshold.update(active: !@anomaly_threshold.active)
    
    respond_to do |format|
      format.html { redirect_to anomaly_threshold_path(@anomaly_threshold), notice: "Threshold has been #{@anomaly_threshold.active? ? 'activated' : 'deactivated'}." }
      format.json { render json: @anomaly_threshold }
      format.turbo_stream { flash.now[:notice] = "Threshold has been #{@anomaly_threshold.active? ? 'activated' : 'deactivated'}." }
    end
  end
  
  def test
    # Test if this threshold would currently trigger an anomaly
    service = AnomalyDetectionService.new(current_tenant)
    is_anomaly = service.anomaly_detected?(@anomaly_threshold)
    
    # Get current value and expected value for context
    current_value = service.get_current_metric_value(@anomaly_threshold)
    expected_value = service.get_expected_value(@anomaly_threshold)
    
    if is_anomaly
      flash[:notice] = "This threshold would detect an anomaly with the current value of #{current_value} (expected: #{expected_value})."
    else
      flash[:notice] = "This threshold would NOT detect an anomaly with the current value of #{current_value} (expected: #{expected_value})."
    end
    
    redirect_to anomaly_threshold_path(@anomaly_threshold)
  end
  
  def export
    @anomaly_thresholds = AnomalyThreshold.all
    @anomaly_thresholds = filter_thresholds(@anomaly_thresholds)
    
    respond_to do |format|
      format.csv { send_data export_thresholds_to_csv(@anomaly_thresholds), filename: "anomaly-thresholds-#{Date.today}.csv" }
      format.json { render json: @anomaly_thresholds }
    end
  end
  
  def import
    # Handle CSV import of thresholds
    if params[:file].present?
      begin
        imported = 0
        
        CSV.foreach(params[:file].path, headers: true) do |row|
          # Convert CSV row to hash with proper keys
          threshold_data = row.to_hash.slice(
            "name", "metric", "threshold_type", "threshold_value", 
            "lookback_period", "severity", "description"
          )
          
          # Handle numeric values
          threshold_data["threshold_value"] = threshold_data["threshold_value"].to_f
          
          # Create the threshold
          threshold = AnomalyThreshold.new(threshold_data)
          
          # Set entity associations if provided
          if row["campaign_id"].present?
            campaign = Campaign.find_by(id: row["campaign_id"])
            threshold.campaign = campaign if campaign
          end
          
          if row["distribution_id"].present?
            distribution = Distribution.find_by(id: row["distribution_id"])
            threshold.distribution = distribution if distribution
          end
          
          # Set metadata
          threshold.metadata = { direction: row["direction"] || "above" }
          
          # Save the threshold
          imported += 1 if threshold.save
        end
        
        redirect_to anomaly_thresholds_path, notice: "Successfully imported #{imported} thresholds."
      rescue => e
        redirect_to anomaly_thresholds_path, alert: "Error importing thresholds: #{e.message}"
      end
    else
      redirect_to anomaly_thresholds_path, alert: "Please select a file to import."
    end
  end
  
  private
  
  def set_anomaly_threshold
    @anomaly_threshold = AnomalyThreshold.find(params[:id])
  end
  
  def anomaly_threshold_params
    params.require(:anomaly_threshold).permit(
      :name, :metric, :threshold_type, :threshold_value, 
      :lookback_period, :severity, :active, :auto_resolve,
      :description, :campaign_id, :distribution_id,
      metadata: [:direction]
    )
  end
  
  def filter_thresholds(thresholds)
    # Filter by scope
    case @scope
    when "global"
      thresholds = thresholds.global
    when "campaign"
      thresholds = thresholds.where.not(campaign_id: nil)
    when "distribution"
      thresholds = thresholds.where.not(distribution_id: nil)
    end
    
    # Filter by campaign
    if @campaign_id.present?
      thresholds = thresholds.for_campaign(@campaign_id)
    end
    
    # Filter by distribution
    if @distribution_id.present?
      thresholds = thresholds.for_distribution(@distribution_id)
    end
    
    # Filter by active status
    if @active_only
      thresholds = thresholds.active
    end
    
    thresholds
  end
  
  def export_thresholds_to_csv(thresholds)
    headers = [
      'ID', 'Name', 'Metric', 'Threshold Type', 'Threshold Value', 
      'Direction', 'Lookback Period', 'Severity', 'Active', 
      'Auto-resolve', 'Campaign', 'Distribution', 'Description'
    ]
    
    CSV.generate(headers: true) do |csv|
      csv << headers
      
      thresholds.each do |threshold|
        campaign_name = threshold.campaign&.name || "N/A"
        distribution_name = threshold.distribution&.name || "N/A"
        
        csv << [
          threshold.id,
          threshold.name,
          threshold.metric,
          threshold.threshold_type,
          threshold.threshold_value,
          threshold.metadata["direction"],
          threshold.lookback_period,
          threshold.severity,
          threshold.active,
          threshold.auto_resolve,
          campaign_name,
          distribution_name,
          threshold.description
        ]
      end
    end
  end
end