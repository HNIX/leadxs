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
  }, default: :active, prefix: true

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
  
  # Endpoint types
  attribute :endpoint_type, :integer
  enum :endpoint_type, {
    post_only: 0,      # Only sends full lead data
    ping_post: 1,      # Supports both ping and post
    ping_only: 2       # Only supports ping/bidding
  }, default: :post_only
  
  # Authentication methods
  attribute :authentication_method, :integer
  enum :authentication_method, {
    none: 0,           # No authentication
    token: 10,         # Simple API token
    basic_auth: 20,    # Username/password basic auth
    oauth2: 30,        # OAuth 2.0
    jwt: 40            # JWT authentication
  }, default: :none, prefix: true
  
  # Validations for authentication fields
  validates :username, :password, presence: true, if: -> { authentication_method_basic_auth? }
  validates :authentication_token, presence: true, if: -> { authentication_method_token? }
  validates :client_id, :client_secret, :token_url, presence: true, if: -> { authentication_method_oauth2? }
  validates :post_endpoint_url, presence: true, if: -> { endpoint_type == "ping_post" }
  validates :api_key_name, presence: true, if: -> { authentication_method_token? }
  
  # Define enum attribute with explicit string type
  attribute :metadata_requirements, :integer
  enum :metadata_requirements, {
    no_metadata: 0,              # No metadata fields required
    include_standard_fields: 1,  # Include standard tracking fields (lead_id, timestamp, etc.)
    include_extended_fields: 2   # Include extended tracking fields
  }, default: :no_metadata

  def self.active
    where(status: :active)
  end

  def active?
    status_active?
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
  
  # Attribute for fallback bidding on errors
  attribute :bid_on_error, :boolean, default: false

  # Check if bidding is enabled for this distribution
  def bidding_enabled?
    # For ping_post and ping_only distributions, we require a base_bid_amount
    if endpoint_type.in?(["ping_post", "ping_only"])
      result = status_active? && base_bid_amount.present? && base_bid_amount > 0
    
      reason = if !status_active?
                 "distribution is not active (status: #{status})"
               elsif !base_bid_amount.present?
                 "base_bid_amount is not set"
               elsif !(base_bid_amount > 0)
                 "base_bid_amount is not greater than 0 (value: #{base_bid_amount})"
               else
                 "bidding is enabled"
               end
    # For post_only distributions, we just need them to be active
    # This allows post_only distributions to participate in ping-post campaigns
    else
      result = status_active? && (base_bid_amount.present? && base_bid_amount > 0)
      
      reason = if !status_active?
                 "distribution is not active (status: #{status})"
               elsif (!base_bid_amount.present? || !(base_bid_amount > 0))
                 "post-only distribution without bid amount (requires manual amount)"
               else
                 "bidding is enabled"
               end
    end
    
    Rails.logger.debug("Distribution #{id} (#{name}) bidding_enabled? => #{result} (#{reason})")
    return result
  end
  
  # Store ping response data for use in post phase
  def store_ping_response(response_data)
    self.ping_response_data = response_data
    save
  end
  
  # Get ping ID from stored response data
  def ping_id
    return nil unless ping_response_data.present?
    
    # Try to extract ping ID from stored response
    begin
      data = JSON.parse(ping_response_data) rescue nil
      return nil unless data.is_a?(Hash)
      
      # If a custom ping_id_field is specified, use that path to extract the ID
      if ping_id_field.present?
        # Split the path by dots and navigate through the nested structure
        path_parts = ping_id_field.split('.')
        value = data
        
        path_parts.each do |part|
          value = value.is_a?(Hash) ? value[part] : nil
          break if value.nil?
        end
        
        return value unless value.nil?
      end
      
      # Fallback to common ping ID field names if custom field not found
      data["ping_id"] || data["id"] || data["request_id"] || 
      data["token"] || data["ref"] || data["reference_id"] ||
      data.dig("data", "ping_id") || data.dig("response", "id")
    rescue
      nil
    end
  end
  
  # Parse and evaluate response against custom response mapping rules
  def evaluate_response(response_data, response_code)
    return true if (200..299).include?(response_code) && response_mapping.blank?
    
    begin
      # Parse response data if it's a string (JSON)
      response_body = response_data.is_a?(String) ? JSON.parse(response_data) : response_data
      
      # If no response mapping is configured, use default HTTP status code check
      return (200..299).include?(response_code) unless response_mapping.present?
      
      # Check for success criteria in the response mapping
      if response_mapping['success_criteria'].present?
        success_criteria = response_mapping['success_criteria']
        
        # Check HTTP status code range if specified
        if success_criteria['status_codes'].present?
          status_range = success_criteria['status_codes']
          unless status_range.any? { |range| range.split('-').map(&:to_i).then { |min, max| (min..max).include?(response_code) } }
            return false
          end
        end
        
        # Check for field based success criteria
        if success_criteria['fields'].present?
          success_criteria['fields'].each do |field_config|
            field_path = field_config['path']
            expected_value = field_config['value']
            operator = field_config['operator'] || 'eq'
            
            # Extract field value using the path
            field_value = extract_field_value(response_body, field_path)
            
            # Compare based on operator
            case operator
            when 'eq'
              return false unless field_value == expected_value
            when 'neq'
              return false unless field_value != expected_value
            when 'contains'
              return false unless field_value.to_s.include?(expected_value.to_s)
            when 'regex'
              return false unless field_value.to_s.match?(Regexp.new(expected_value.to_s))
            end
          end
        end
        
        return true
      end
      
      # Default to HTTP status code check if no specific criteria matched
      (200..299).include?(response_code)
    rescue => e
      Rails.logger.error("Error evaluating response: #{e.message}")
      # Default to HTTP status code check on error
      (200..299).include?(response_code)
    end
  end
  
  # Extract error message from response based on mapping
  def extract_error_message(response_data, response_code)
    return "HTTP Error: #{response_code}" unless (200..299).include?(response_code) || response_mapping.blank?
    
    begin
      # Parse response data if it's a string (JSON)
      response_body = response_data.is_a?(String) ? JSON.parse(response_data) : response_data
      
      # If error fields are configured, extract the error message
      if response_mapping['error_fields'].present?
        response_mapping['error_fields'].each do |field_path|
          error_message = extract_field_value(response_body, field_path)
          return error_message if error_message.present?
        end
      end
      
      # Generic error message based on HTTP status
      "HTTP Error: #{response_code}"
    rescue => e
      Rails.logger.error("Error extracting error message: #{e.message}")
      "HTTP Error: #{response_code}"
    end
  end
  
  # Helper method to extract a value from a nested hash using a dot-notation path
  def extract_field_value(data, path)
    path_parts = path.split('.')
    value = data
    
    path_parts.each do |part|
      if value.is_a?(Hash) 
        value = value[part] || value[part.to_sym]
      else
        return nil
      end
    end
    
    value
  end
  
  # Check if this distribution can use fallback bidding
  def can_use_fallback_bid?
    bid_on_error && base_bid_amount.present? && base_bid_amount > 0
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
