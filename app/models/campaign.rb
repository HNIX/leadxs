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
  
  # Validations
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :campaign_type, presence: true, inclusion: { in: CAMPAIGN_TYPES }
  validates :distribution_method, presence: true, inclusion: { in: DISTRIBUTION_METHODS }
  validates :bid_timeout_seconds, numericality: { greater_than_or_equal_to: 5, less_than_or_equal_to: 300 }, if: :use_bidding_system?
  validates :multi_distribution_strategy, presence: true, inclusion: { in: MULTI_DISTRIBUTION_STRATEGIES }
  validates :max_distributions, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }
  
  # Validate schedule times if scheduling is enabled
  validates :distribution_schedule_days, presence: true, if: :distribution_schedule_enabled?
  validates :distribution_schedule_start_time, presence: true, if: :distribution_schedule_enabled?
  validates :distribution_schedule_end_time, presence: true, if: :distribution_schedule_enabled?
  validate :validate_schedule_times, if: :distribution_schedule_enabled?
  
  # Campaign status methods
  def active?
    status == 'active'
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
  
  # Check if bidding system should be used
  def use_bidding_system?
    # Bidding is used for ping-post campaigns with a bidding distribution method
    campaign_type == 'ping_post' && distribution_method.in?(['highest_bid', 'weighted_random', 'waterfall'])
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
    
    # Further limit to distributions set up for bidding
    bidding_enabled = eligible.select { |dist| dist.respond_to?(:bidding_enabled?) && dist.bidding_enabled? }
    Rails.logger.info("Campaign #{id} has #{bidding_enabled.count} distributions with bidding enabled")
    
    # Log which distributions are not bidding enabled for debugging
    if bidding_enabled.count < eligible.count
      eligible.each do |dist|
        unless dist.respond_to?(:bidding_enabled?) && dist.bidding_enabled?
          if !dist.respond_to?(:bidding_enabled?)
            Rails.logger.warn("Distribution #{dist.id} doesn't respond to bidding_enabled?")
          elsif !dist.bidding_enabled?
            Rails.logger.warn("Distribution #{dist.id} has bidding disabled (base_bid_amount: #{dist.base_bid_amount})")
          end
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
  
  private
  
  def validate_schedule_times
    return unless distribution_schedule_start_time && distribution_schedule_end_time
    
    if distribution_schedule_end_time <= distribution_schedule_start_time
      errors.add(:distribution_schedule_end_time, "must be after the start time")
    end
  end
  
  def generate_fields_from_vertical
    CampaignFieldGenerator.new(self).generate_fields!
  end
end
