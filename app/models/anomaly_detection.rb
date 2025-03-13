class AnomalyDetection < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :anomaly_threshold
  belongs_to :campaign, optional: true
  belongs_to :distribution, optional: true
  belongs_to :user, optional: true
  
  validates :metric, :value, :detected_at, :severity, presence: true
  
  store_accessor :context_data, []
  
  enum :severity, {
    warning: "warning",
    critical: "critical"
  }
  
  enum :status, {
    open: "open",
    acknowledged: "acknowledged",
    resolved: "resolved"
  }
  
  scope :recent, -> { order(detected_at: :desc) }
  scope :unresolved, -> { where(resolved_at: nil) }
  scope :open_anomalies, -> { where(status: :open) }
  scope :critical, -> { where(severity: :critical) }
  scope :in_last_day, -> { where(detected_at: 24.hours.ago..Time.current) }
  scope :in_last_week, -> { where(detected_at: 7.days.ago..Time.current) }
  scope :for_campaign, ->(campaign_id) { where(campaign_id: campaign_id) }
  scope :for_distribution, ->(distribution_id) { where(distribution_id: distribution_id) }
  scope :for_metric, ->(metric) { where(metric: metric) }
  
  before_create :set_detected_at
  
  # Acknowledge the anomaly
  def acknowledge!(user = nil)
    update(
      status: :acknowledged,
      acknowledged_at: Time.current,
      user: user
    )
  end
  
  # Resolve the anomaly
  def resolve!(user = nil, notes = nil)
    update(
      status: :resolved,
      resolved_at: Time.current,
      user: user,
      notes: notes
    )
  end
  
  # Calculate time since detection
  def time_since_detection
    ((Time.current - detected_at) / 1.hour).round(1)
  end
  
  # Human-readable deviation description
  def deviation_description
    if deviation_percent.present?
      direction = value > expected_value ? "higher" : "lower"
      "#{deviation_percent.abs.round(2)}% #{direction} than expected"
    else
      "Unknown deviation"
    end
  end
  
  # Get the location context (account-wide, campaign, or distribution)
  def location_context
    if campaign.present?
      "Campaign: #{campaign.name}"
    elsif distribution.present?
      "Distribution: #{distribution.name}"
    else
      "Account-wide"
    end
  end
  
  # Get the status with timestamp
  def status_with_time
    case status
    when "open"
      "Open since #{detected_at.strftime('%b %d, %H:%M')}"
    when "acknowledged"
      "Acknowledged #{acknowledged_at.strftime('%b %d, %H:%M')}"
    when "resolved"
      "Resolved #{resolved_at.strftime('%b %d, %H:%M')}"
    end
  end
  
  # Generate a summary of the anomaly
  def summary
    "#{severity.upcase}: #{metric_name} is #{deviation_description} in #{location_context}"
  end
  
  # Get metric name from AnomalyThreshold available metrics
  def metric_name
    metric_info = AnomalyThreshold.available_metrics.find { |m| m[:key] == metric }
    metric_info ? metric_info[:name] : metric
  end
  
  # Return the entity this anomaly is related to
  def related_entity
    campaign || distribution || account
  end
  
  private
  
  def set_detected_at
    self.detected_at ||= Time.current
  end
end
