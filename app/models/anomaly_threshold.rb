class AnomalyThreshold < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :campaign, optional: true
  belongs_to :distribution, optional: true
  has_many :anomaly_detections, dependent: :destroy
  
  validates :name, :metric, :threshold_type, :threshold_value, :lookback_period, :severity, presence: true
  
  store_accessor :metadata, []
  
  enum :threshold_type, {
    absolute: "absolute",
    percentage: "percentage", 
    std_dev: "std_dev"
  }, prefix: :threshold
  
  enum :lookback_period, {
    hourly: "hourly",
    daily: "daily",
    weekly: "weekly",
    monthly: "monthly"
  }
  
  enum :severity, {
    warning: "warning",
    critical: "critical"
  }
  
  scope :active, -> { where(active: true) }
  scope :global, -> { where(campaign_id: nil, distribution_id: nil) }
  scope :for_campaign, ->(campaign_id) { where(campaign_id: campaign_id) }
  scope :for_distribution, ->(distribution_id) { where(distribution_id: distribution_id) }
  scope :for_metric, ->(metric) { where(metric: metric) }
  
  # Common metrics available for anomaly detection
  def self.available_metrics
    [
      # Bid performance metrics
      {key: "bid_amount_avg", name: "Average Bid Amount", description: "Average amount of bids received"},
      {key: "bid_count", name: "Bid Count", description: "Number of bids received"},
      {key: "acceptance_rate", name: "Acceptance Rate", description: "Percentage of bids that were accepted"},
      {key: "win_rate", name: "Win Rate", description: "Percentage of bid requests that resulted in a won bid"},
      {key: "response_time_avg", name: "Average Response Time", description: "Average time to receive a bid response"},
      
      # Revenue metrics
      {key: "revenue_total", name: "Total Revenue", description: "Total revenue from accepted bids"},
      {key: "revenue_per_lead", name: "Revenue per Lead", description: "Average revenue per lead"},
      {key: "margin_percent", name: "Margin Percentage", description: "Profit margin percentage"},
      
      # Compliance metrics
      {key: "compliance_rate", name: "Compliance Rate", description: "Percentage of leads meeting compliance requirements"},
      {key: "consent_verification_rate", name: "Consent Verification Rate", description: "Percentage of leads with verified consent"},
      {key: "documentation_complete_rate", name: "Documentation Complete Rate", description: "Percentage of leads with complete documentation"},
      
      # Field-related metrics
      {key: "field_completion_rate", name: "Field Completion Rate", description: "Percentage of fields completed in submitted leads"},
      {key: "validation_failure_rate", name: "Validation Failure Rate", description: "Percentage of leads failing validation rules"},
      
      # Lead quality metrics
      {key: "lead_rejection_rate", name: "Lead Rejection Rate", description: "Percentage of leads rejected by buyers"},
      {key: "distribution_failure_rate", name: "Distribution Failure Rate", description: "Percentage of lead distributions that failed"}
    ]
  end
  
  # Check if this threshold applies to a specific entity (campaign or distribution)
  def entity_specific?
    campaign_id.present? || distribution_id.present?
  end
  
  # Get the scope for the threshold (account, campaign, or distribution level)
  def scope_description
    if campaign_id.present?
      "Campaign: #{campaign.name}" 
    elsif distribution_id.present?
      "Distribution: #{distribution.name}"
    else
      "Account-wide"
    end
  end
  
  # Human-readable description of the threshold condition
  def condition_description
    case threshold_type
    when "absolute"
      "#{metric_name} #{comparison_operator} #{threshold_value}"
    when "percentage"
      "#{metric_name} changes by #{threshold_value}% or more" 
    when "std_dev"
      "#{metric_name} deviates by #{threshold_value} standard deviations"
    end
  end
  
  # Get readable metric name from key
  def metric_name
    metric_info = self.class.available_metrics.find { |m| m[:key] == metric }
    metric_info ? metric_info[:name] : metric
  end
  
  # Get comparison operator based on metadata
  def comparison_operator
    if metadata["direction"] == "below"
      "<"
    else
      ">"
    end
  end
end
