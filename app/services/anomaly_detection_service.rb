class AnomalyDetectionService
  attr_reader :account

  def initialize(account)
    @account = account
  end

  # Check all active thresholds and detect anomalies
  def detect_anomalies!
    results = {
      detected: [],
      checked: 0,
      errors: []
    }
    
    # Get all active thresholds
    thresholds = AnomalyThreshold.active
    results[:checked] = thresholds.count
    
    thresholds.each do |threshold|
      begin
        # Check this specific threshold
        if anomaly_detected?(threshold)
          # Create an anomaly record if detected
          anomaly = create_anomaly_record(threshold)
          
          # Track the result
          results[:detected] << {
            id: anomaly.id,
            metric: anomaly.metric,
            severity: anomaly.severity,
            summary: anomaly.summary
          }
          
          # Send notifications if required
          notify_about_anomaly(anomaly)
        end
      rescue => e
        results[:errors] << {
          threshold_id: threshold.id,
          metric: threshold.metric,
          error: e.message
        }
      end
    end
    
    results
  end
  
  # Check if an anomaly exists for a specific threshold
  def anomaly_detected?(threshold)
    # Get metric value for the current period
    current_value = get_current_metric_value(threshold)
    return false if current_value.nil?
    
    # Get expected value based on historical data
    expected_value = get_expected_value(threshold)
    return false if expected_value.nil? || expected_value == 0
    
    # Calculate deviation 
    deviation = calculate_deviation(current_value, expected_value, threshold)
    
    # Compare based on threshold type
    case threshold.threshold_type
    when "absolute"
      # Check if absolute value exceeds threshold
      if threshold.metadata["direction"] == "below"
        current_value < threshold.threshold_value
      else
        current_value > threshold.threshold_value
      end
    when "percentage"
      # Check if percentage change exceeds threshold
      deviation.abs >= threshold.threshold_value
    when "std_dev"
      # Check if standard deviation exceeds threshold
      std_dev = calculate_standard_deviation(threshold)
      (current_value - expected_value).abs > (std_dev * threshold.threshold_value)
    else
      false
    end
  end
  
  # Create an anomaly detection record
  def create_anomaly_record(threshold)
    current_value = get_current_metric_value(threshold)
    expected_value = get_expected_value(threshold)
    deviation = calculate_deviation(current_value, expected_value, threshold)
    
    # Context data holds additional information for analysis
    context = {
      period_type: threshold.lookback_period,
      detection_method: threshold.threshold_type,
      threshold_config: {
        value: threshold.threshold_value,
        direction: threshold.metadata["direction"]
      },
      historical_data: get_historical_data_summary(threshold)
    }
    
    anomaly = AnomalyDetection.create!(
      metric: threshold.metric,
      value: current_value,
      expected_value: expected_value,
      deviation_percent: deviation,
      severity: threshold.severity,
      anomaly_threshold: threshold,
      detected_at: Time.current,
      context_data: context,
      campaign_id: threshold.campaign_id,
      distribution_id: threshold.distribution_id
    )
    
    anomaly
  end
  
  # Send notifications for detected anomalies
  def notify_about_anomaly(anomaly)
    # Create a notification record
    notification = Notification.create!(
      recipient: account,
      type: "AnomalyNotification", 
      params: {
        anomaly_id: anomaly.id,
        summary: anomaly.summary,
        severity: anomaly.severity,
        metric: anomaly.metric,
        detected_at: anomaly.detected_at
      }
    )
    
    # Deliver notifications to users
    User.all.each do |user|
      # Only send to users who have notification preferences enabled
      next unless user.preferences.dig("notifications", "anomalies", "enabled")
      
      # Skip if the user has severity-based filtering
      if user.preferences.dig("notifications", "anomalies", "critical_only") && 
         anomaly.severity != "critical"
        next
      end
      
      # Send notification to the user
      notification.deliver(user)
      
      # Send email if user has email notifications enabled
      if user.preferences.dig("notifications", "anomalies", "email_enabled")
        # AnomalyMailer.anomaly_detected(user, anomaly).deliver_later
      end
    end
  end
  
  # Get the current metric value 
  def get_current_metric_value(threshold)
    # Time range for the current period
    time_range = get_time_range_for_period(threshold.lookback_period)
    
    # Apply any entity-specific filtering
    campaign_id = threshold.campaign_id
    distribution_id = threshold.distribution_id
    
    # Calculate the metric value based on metric type
    case threshold.metric
    when "bid_amount_avg"
      bids = filter_bids(time_range, campaign_id, distribution_id)
      bids.average(:amount)&.to_f || 0
    when "bid_count"
      bids = filter_bids(time_range, campaign_id, distribution_id)
      bids.count
    when "acceptance_rate"
      bids = filter_bids(time_range, campaign_id, distribution_id)
      total = bids.count
      return 0 if total == 0
      (bids.accepted.count.to_f / total) * 100
    when "win_rate"
      requests = filter_bid_requests(time_range, campaign_id)
      total = requests.count
      return 0 if total == 0
      completed = requests.where(status: :completed).count
      (completed.to_f / total) * 100
    when "response_time_avg"
      bids = filter_bids(time_range, campaign_id, distribution_id)
      bids.joins(:api_request)
          .where.not(api_requests: { duration_ms: nil })
          .average('api_requests.duration_ms')&.to_f || 0
    when "revenue_total"
      bids = filter_bids(time_range, campaign_id, distribution_id).accepted
      bids.sum(:amount)
    when "revenue_per_lead"
      bids = filter_bids(time_range, campaign_id, distribution_id).accepted
      leads = bids.count
      return 0 if leads == 0
      bids.sum(:amount) / leads
    when "compliance_rate"
      leads = filter_leads(time_range, campaign_id)
      total = leads.count
      return 0 if total == 0
      compliant = account.compliance_records
                         .where(created_at: time_range)
                         .where("data->>'compliant' = 'true'")
                         .count
      (compliant.to_f / total) * 100
    when "consent_verification_rate"
      consents = account.consent_records.where(created_at: time_range)
      total = consents.count
      return 0 if total == 0
      verified = consents.where(revoked: false)
                         .where("expires_at IS NULL OR expires_at > ?", Time.current)
                         .count
      (verified.to_f / total) * 100
    when "field_completion_rate"
      # Complex calculation involving lead data
      leads = filter_leads(time_range, campaign_id)
      return 0 if leads.empty?
      
      # This would need to be calculated based on your specific data structure
      # Example implementation:
      completion_rates = []
      leads.each do |lead|
        if lead.lead_data && lead.lead_data.data
          total_fields = lead.lead_data.data.keys.count
          filled_fields = lead.lead_data.data.reject { |_, v| v.blank? }.count
          completion_rates << (filled_fields.to_f / total_fields) * 100 if total_fields > 0
        end
      end
      
      completion_rates.empty? ? 0 : (completion_rates.sum / completion_rates.size)
    when "validation_failure_rate"
      # You would need to implement this based on how validation results are stored
      # This is a placeholder implementation:
      lead_count = filter_leads(time_range, campaign_id).count
      return 0 if lead_count == 0
      
      # Assuming lead activity logs track validation failures
      validation_failures = account.lead_activity_logs
                                  .where(created_at: time_range)
                                  .where(event_type: "validation_failure")
                                  .count
      
      (validation_failures.to_f / lead_count) * 100
    when "lead_rejection_rate"
      leads = filter_leads(time_range, campaign_id)
      total = leads.count
      return 0 if total == 0
      
      rejected = leads.where(status: :rejected).count
      (rejected.to_f / total) * 100
    when "distribution_failure_rate"
      api_requests = account.api_requests
                           .where(created_at: time_range)
                           .where(request_type: "distribution")
      
      total = api_requests.count
      return 0 if total == 0
      
      failures = api_requests.where(status: "error").count
      (failures.to_f / total) * 100
    else
      # For custom metrics, return 0 or handle specially
      0
    end
  end
  
  # Get expected value based on historical data
  def get_expected_value(threshold)
    # Get historical periods based on lookback period
    historical_periods = get_historical_periods(threshold.lookback_period, 4)
    
    # Calculate values for each historical period
    historical_values = []
    
    historical_periods.each do |period_range|
      # Save the current time range
      @current_time_range = get_time_range_for_period(threshold.lookback_period)
      
      # Set time range to historical period
      @override_time_range = period_range
      
      # Get the value
      value = get_current_metric_value(threshold)
      historical_values << value if value
      
      # Reset the time range override
      @override_time_range = nil
    end
    
    # Calculate the expected value (average of historical periods)
    historical_values.empty? ? nil : historical_values.sum / historical_values.size
  end
  
  # Calculate standard deviation of historical values
  def calculate_standard_deviation(threshold)
    # Get historical periods based on lookback period
    historical_periods = get_historical_periods(threshold.lookback_period, 6)
    
    # Calculate values for each historical period
    historical_values = []
    
    historical_periods.each do |period_range|
      # Save the current time range
      @current_time_range = get_time_range_for_period(threshold.lookback_period)
      
      # Set time range to historical period
      @override_time_range = period_range
      
      # Get the value
      value = get_current_metric_value(threshold)
      historical_values << value if value
      
      # Reset the time range override
      @override_time_range = nil
    end
    
    return 0 if historical_values.empty?
    
    # Calculate mean
    mean = historical_values.sum / historical_values.size
    
    # Calculate sum of squared differences
    sum_squared_diffs = historical_values.inject(0) { |sum, value| sum + (value - mean) ** 2 }
    
    # Calculate standard deviation
    Math.sqrt(sum_squared_diffs / historical_values.size)
  end
  
  # Calculate percentage deviation between current and expected values
  def calculate_deviation(current, expected, threshold)
    return 0 if expected.nil? || expected == 0
    
    # Calculate percentage difference
    ((current - expected) / expected) * 100
  end
  
  # Get historical periods based on lookback period
  def get_historical_periods(period_type, num_periods = 4)
    periods = []
    
    case period_type
    when "hourly"
      num_periods.times do |i|
        periods << ((i+1).hours.ago..(i).hours.ago)
      end
    when "daily"
      num_periods.times do |i|
        periods << ((i+1).days.ago..(i).days.ago)
      end
    when "weekly"
      num_periods.times do |i|
        periods << ((i+1).weeks.ago..(i).weeks.ago)
      end
    when "monthly"
      num_periods.times do |i|
        periods << ((i+1).months.ago..(i).months.ago)
      end
    end
    
    periods
  end
  
  # Get time range for the current period
  def get_time_range_for_period(period_type)
    # If there's an override for testing historical values, use it
    return @override_time_range if @override_time_range.present?
    
    case period_type
    when "hourly"
      1.hour.ago..Time.current
    when "daily"
      1.day.ago..Time.current
    when "weekly"
      1.week.ago..Time.current
    when "monthly"
      1.month.ago..Time.current
    else
      1.day.ago..Time.current # Default to daily
    end
  end
  
  # Get a summary of historical data for context
  def get_historical_data_summary(threshold)
    # Get historical periods
    periods = get_historical_periods(threshold.lookback_period, 4)
    
    # Calculate values for each period
    summary = []
    
    periods.each_with_index do |period, index|
      # Override time range to get historical value
      @override_time_range = period
      
      # Calculate value for this period
      value = get_current_metric_value(threshold)
      
      # Add to summary
      summary << {
        period: index + 1,
        start: period.begin.iso8601,
        end: period.end.iso8601,
        value: value
      }
      
      # Reset override
      @override_time_range = nil
    end
    
    summary
  end
  
  # Helper to filter bids based on criteria
  def filter_bids(time_range, campaign_id = nil, distribution_id = nil)
    bids = Bid.where(created_at: time_range)
    
    if campaign_id
      bids = bids.joins(:bid_request).where(bid_requests: { campaign_id: campaign_id })
    end
    
    if distribution_id
      bids = bids.where(distribution_id: distribution_id)
    end
    
    bids
  end
  
  # Helper to filter bid requests based on criteria
  def filter_bid_requests(time_range, campaign_id = nil)
    requests = BidRequest.where(created_at: time_range)
    requests = requests.where(campaign_id: campaign_id) if campaign_id
    requests
  end
  
  # Helper to filter leads based on criteria
  def filter_leads(time_range, campaign_id = nil)
    leads = Lead.where(created_at: time_range)
    leads = leads.where(campaign_id: campaign_id) if campaign_id
    leads
  end
end