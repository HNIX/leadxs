class Campaign < ApplicationRecord
  # Add acts_as_tenant association
  acts_as_tenant :account
  
  belongs_to :vertical
  has_many :campaign_fields, -> { order(position: :asc) }, dependent: :destroy
  has_many :calculated_fields, dependent: :destroy
  has_many :validation_rules, -> { order(position: :asc) }, as: :validatable, dependent: :destroy
  has_many :sources, dependent: :destroy
  has_many :campaign_distributions, dependent: :destroy
  has_many :distributions, through: :campaign_distributions
  has_many :leads, dependent: :destroy
  has_many :source_filters, -> { where(type: 'SourceFilter') }, class_name: 'SourceFilter', dependent: :destroy, foreign_key: 'campaign_id'
  has_many :distribution_filters, -> { where(type: 'DistributionFilter') }, class_name: 'DistributionFilter', dependent: :destroy, foreign_key: 'campaign_id'
  has_many :bid_requests, dependent: :destroy
  has_many :bid_analytic_snapshots, dependent: :nullify
  has_many :form_builders, dependent: :destroy
  
  # Define enrichment processors attribute with default value
  def enrichment_processors
    []
  end
  
  # Constants for campaign types and distribution methods
  CAMPAIGN_TYPES = ['ping_post', 'direct', 'calls'].freeze
  DISTRIBUTION_METHODS = ['highest_bid', 'round_robin', 'weighted_random', 'waterfall'].freeze
  STATUSES = ['draft', 'active', 'paused', 'archived'].freeze
  MULTI_DISTRIBUTION_STRATEGIES = ['sequential', 'parallel', 'single'].freeze
  
  # Define allowed distribution methods per campaign type
  ALLOWED_DISTRIBUTION_METHODS = {
    'ping_post' => ['highest_bid', 'weighted_random', 'waterfall', 'round_robin'],
    'direct' => ['round_robin', 'weighted_random', 'waterfall'],
    'calls' => ['round_robin', 'weighted_random']
  }.freeze
  
  # Validations
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :campaign_type, presence: true, inclusion: { in: CAMPAIGN_TYPES }
  validates :distribution_method, presence: true, inclusion: { in: DISTRIBUTION_METHODS }
  validates :bid_timeout_seconds, numericality: { greater_than_or_equal_to: 5, less_than_or_equal_to: 300 }, if: :use_bidding_system?
  validates :multi_distribution_strategy, presence: true, inclusion: { in: MULTI_DISTRIBUTION_STRATEGIES }
  validates :max_distributions, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }
  validate :validate_distribution_method_for_campaign_type
  validate :validate_campaign_dates
  
  # Validate schedule times if scheduling is enabled
  validates :distribution_schedule_days, presence: true, if: :distribution_schedule_enabled?
  validates :distribution_schedule_start_time, presence: true, if: :distribution_schedule_enabled?
  validates :distribution_schedule_end_time, presence: true, if: :distribution_schedule_enabled?
  validate :validate_schedule_times, if: :distribution_schedule_enabled?
  
  # Campaign status methods
  def active?
    status == 'active' && currently_in_schedule_period?
  end
  
  def paused?
    status == 'paused'
  end
  
  def archived?
    status == 'archived'
  end
  
  def draft?
    status == 'draft'
  end
  
  # Check if campaign is currently in its scheduled period based on dates
  def currently_in_schedule_period?
    today = Date.current
    return true if start_date.nil? && end_date.nil?
    return today >= start_date if start_date.present? && end_date.nil?
    return today <= end_date if start_date.nil? && end_date.present?
    (start_date..end_date).cover?(today)
  end
  
  # Check if bidding system should be used
  def use_bidding_system?
    # Bidding is used for ping-post campaigns with a bidding distribution method
    campaign_type == 'ping_post' && distribution_method.in?(['highest_bid', 'weighted_random', 'waterfall'])
  end
  
  # Check if debug mode is enabled
  def debug_mode?
    debug_mode == true
  end
  
  # Get the appropriate distribution workflow type based on campaign settings
  def distribution_workflow
    if campaign_type == 'direct'
      :direct_post
    elsif campaign_type == 'ping_post' && use_bidding_system?
      :ping_post_with_bidding
    elsif campaign_type == 'ping_post' && !use_bidding_system?
      :ping_post_without_bidding
    elsif campaign_type == 'calls'
      :call_routing
    else
      :direct_post # default fallback
    end
  end
  
  # Handle days as array
  def distribution_schedule_days
    self[:distribution_schedule_days].present? ? JSON.parse(self[:distribution_schedule_days]) : []
  end
  
  def distribution_schedule_days=(value)
    self[:distribution_schedule_days] = value.is_a?(Array) ? value.to_json : value
  end

  after_create :generate_fields_from_vertical
  
  # Find eligible sources for given lead data
  def eligible_sources(lead_data)
    SourceFilter.filter_sources(sources.active, lead_data, self)
  end
  
  # Find eligible distributions for given lead data
  def eligible_distributions(lead_data)
    DistributionFilter.filter_distributions(distributions.active, lead_data, self)
  end
  
  # Find eligible distributions for bidding with given anonymized data
  def eligible_distributions_for_bidding(anonymized_data)
    Rails.logger.info("Campaign#eligible_distributions_for_bidding called for campaign #{id}")
    
    unless distribution_method.in?(['highest_bid', 'weighted_random', 'waterfall'])
      Rails.logger.warn("Campaign #{id} has distribution_method '#{distribution_method}' not compatible with bidding")
      return []
    end
    
    # Apply filters to determine eligible distributions
    Rails.logger.info("Campaign #{id} getting filtered eligible distributions")
    eligible = eligible_distributions(anonymized_data)
    Rails.logger.info("Campaign #{id} has #{eligible.count} distributions after filtering")
    
    # For ping-post campaigns, we need to include:
    # 1. ping_post distributions with bidding enabled
    # 2. ping_only distributions with bidding enabled
    # 3. post_only distributions with bidding enabled
    if campaign_type == 'ping_post'
      bidding_enabled = eligible.select do |dist|
        # Include all types of distributions that have bidding enabled
        dist.respond_to?(:bidding_enabled?) && dist.bidding_enabled?
      end
    else
      # For other campaign types, only include distributions set up for bidding
      bidding_enabled = eligible.select do |dist|
        dist.respond_to?(:bidding_enabled?) && 
        dist.bidding_enabled? && 
        dist.endpoint_type.in?(["ping_post", "ping_only"])
      end
    end
    
    Rails.logger.info("Campaign #{id} has #{bidding_enabled.count} distributions with bidding enabled")
    
    # Log which distributions are not bidding enabled for debugging
    if bidding_enabled.count < eligible.count
      eligible.each do |dist|
        unless bidding_enabled.include?(dist)
          reason = if !dist.respond_to?(:bidding_enabled?)
                    "doesn't respond to bidding_enabled?"
                  elsif !dist.bidding_enabled?
                    "has bidding disabled (base_bid_amount: #{dist.base_bid_amount})"
                  else
                    "unknown reason"
                  end
          
          Rails.logger.warn("Distribution #{dist.id} (#{dist.name}) excluded from bidding: #{reason}")
        end
      end
    end
    
    bidding_enabled
  end
  
  # Get all eligible entities (sources and distributions) for given lead data
  def eligible_entities(lead_data)
    FilterService.evaluate_filters(lead_data, self)
  end
  
  # Check if campaign is ready for form building
  def ready_for_form_builder?
    # Campaign must have fields
    return false if campaign_fields.empty?
    
    # Campaign must have at least one required field
    #return false unless campaign_fields.where(required: true).exists?
    
    # Campaign should be in draft, active or paused status (not archived)
    return false if archived?
    
    true
  end
  
  # Get the available distribution methods for this campaign type
  def available_distribution_methods
    ALLOWED_DISTRIBUTION_METHODS[campaign_type] || []
  end
  
  # Get campaign type-specific configuration requirements
  def configuration_requirements
    base_requirements = {
      basic_info: true,
      fields: true,
      validation_rules: true,
      sources: true,
      distributions: true
    }
    
    case campaign_type
    when 'ping_post'
      base_requirements.merge({
        bidding_settings: use_bidding_system?,
        ping_endpoints: true,
        post_endpoints: true,
        bid_timeout: use_bidding_system?
      })
    when 'direct'
      base_requirements.merge({
        bidding_settings: false,
        ping_endpoints: false,
        post_endpoints: true,
        conversion_tracking: true
      })
    when 'calls'
      base_requirements.merge({
        bidding_settings: false,
        call_routing: true,
        recording_settings: true,
        quality_metrics: true
      })
    else
      base_requirements
    end
  end
  
  # Check if campaign configuration is complete
  def configuration_complete?
    reqs = configuration_requirements
    
    # Basic checks for all campaign types
    return false if campaign_fields.empty?
    return false if sources.active.empty?
    return false if distributions.active.empty?
    
    # Campaign type-specific checks
    case campaign_type
    when 'ping_post'
      if use_bidding_system?
        return false if bid_timeout_seconds.nil?
      end
    when 'direct'
      # Direct campaign specific checks
    when 'calls'
      # Call campaign specific checks
    end
    
    true
  end

  private
  
  def validate_distribution_method_for_campaign_type
    return unless campaign_type.present? && distribution_method.present?
    
    allowed_methods = ALLOWED_DISTRIBUTION_METHODS[campaign_type] || []
    
    unless allowed_methods.include?(distribution_method)
      errors.add(:distribution_method, "#{distribution_method} is not valid for #{campaign_type} campaigns. Allowed methods: #{allowed_methods.join(', ')}")
    end
  end
  
  def validate_schedule_times
    return unless distribution_schedule_start_time && distribution_schedule_end_time
    
    if distribution_schedule_end_time <= distribution_schedule_start_time
      errors.add(:distribution_schedule_end_time, "must be after the start time")
    end
  end
  
  def validate_campaign_dates
    return unless start_date.present? && end_date.present?
    
    if end_date < start_date
      errors.add(:end_date, "must be after the start date")
    end
  end
  
  def generate_fields_from_vertical
    CampaignFieldGenerator.new(self).generate_fields!
  end
end
