class Distribution < ApplicationRecord
  acts_as_tenant :account

  belongs_to :company
  has_many :campaign_distributions, dependent: :destroy
  has_many :campaigns, through: :campaign_distributions
  has_many :headers, dependent: :destroy
  has_many :api_requests, as: :requestable, dependent: :destroy
  has_many :leads, through: :api_requests
  has_many :bids, dependent: :destroy
  has_many :bid_analytic_snapshots, dependent: :nullify

  accepts_nested_attributes_for :headers, reject_if: :all_blank, allow_destroy: true

  validates :name, presence: true
  validates :endpoint_url, presence: true
  validates :request_method, presence: true
  validates :request_format, presence: true
  
  enum :status, {
    active: 0,
    paused: 1,
    archived: 2
  }, default: :active

  enum :request_method, {
    get: 0,
    post: 1,
    put: 2,
    patch: 3
  }, default: :post

  enum :request_format, {
    form: 0,
    json: 1,
    xml: 2
  }, default: :json
  
  enum :metadata_requirements, {
    no_metadata: 0,              # No metadata fields required
    include_standard_fields: 1,  # Include standard tracking fields (lead_id, timestamp, etc.)
    include_extended_fields: 2   # Include extended tracking fields
  }, default: :no_metadata

  def self.active
    where(status: :active)
  end

  def active?
    status == "active"
  end
  
  # Bidding configuration
  enum :bidding_strategy, {
    manual: 0,          # Fixed amount for all leads
    rule_based: 10,     # Apply rules based on lead attributes
    dynamic: 20         # Use machine learning/optimization
  }, default: :manual
  
  validates :base_bid_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :min_bid_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_bid_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :validate_bid_amounts
  
  # Calculate bid amount for a lead based on its data
  def calculate_bid_amount(lead_data)
    # Start with base amount
    amount = base_bid_amount || 0.0
    
    case bidding_strategy
    when "manual"
      # Just use the base amount
      amount
    when "rule_based"
      # Apply rules based on lead data
      # This would be more complex in a production system
      apply_bidding_rules(amount, lead_data)
    when "dynamic"
      # Dynamic bidding based on machine learning
      # This would likely call an external service
      dynamic_bid_calculation(amount, lead_data)
    else
      amount
    end
  end
  
  # Check if bidding is enabled for this distribution
  def bidding_enabled?
    # Enable bidding if the base amount is set and the distribution is active
    active? && base_bid_amount.present? && base_bid_amount > 0
  end
  
  private
  
  def validate_bid_amounts
    return unless min_bid_amount.present? && max_bid_amount.present?
    
    if max_bid_amount < min_bid_amount
      errors.add(:max_bid_amount, "must be greater than minimum bid amount")
    end
  end
  
  def apply_bidding_rules(base_amount, lead_data)
    # Example rules - these would be configured in a real system
    amount = base_amount
    
    # Apply modifiers based on lead data
    # For example, zip code premiums
    if lead_data["zip"].present? && premium_zip_codes.include?(lead_data["zip"])
      amount *= 1.2 # 20% premium for high-value zip codes
    end
    
    # Ensure amount is within bounds
    enforce_bid_limits(amount)
  end
  
  def dynamic_bid_calculation(base_amount, lead_data)
    # This would call an ML model in production
    # For now, just use the base amount with some randomness
    amount = base_amount * (0.9 + rand * 0.2) # +/- 10%
    
    # Ensure amount is within bounds
    enforce_bid_limits(amount)
  end
  
  def enforce_bid_limits(amount)
    # Apply minimum bid if set
    amount = [amount, min_bid_amount].max if min_bid_amount.present?
    
    # Apply maximum bid if set
    amount = [amount, max_bid_amount].min if max_bid_amount.present?
    
    amount
  end
  
  def premium_zip_codes
    # This would come from a configuration in production
    ["90210", "10001", "94105", "60007"]
  end
end
