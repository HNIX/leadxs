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
  
  # Constants for campaign types and distribution methods
  CAMPAIGN_TYPES = ['ping_post', 'direct', 'calls'].freeze
  DISTRIBUTION_METHODS = ['highest_bid', 'round_robin', 'weighted_random', 'waterfall'].freeze
  STATUSES = ['draft', 'active', 'paused', 'archived'].freeze
  
  # Validations
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :campaign_type, presence: true, inclusion: { in: CAMPAIGN_TYPES }
  validates :distribution_method, presence: true, inclusion: { in: DISTRIBUTION_METHODS }
  
  # Validate schedule times if scheduling is enabled
  validates :distribution_schedule_days, presence: true, if: :distribution_schedule_enabled?
  validates :distribution_schedule_start_time, presence: true, if: :distribution_schedule_enabled?
  validates :distribution_schedule_end_time, presence: true, if: :distribution_schedule_enabled?
  validate :validate_schedule_times, if: :distribution_schedule_enabled?
  
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
    return [] unless distribution_method.in?(['highest_bid', 'weighted_random', 'waterfall'])
    
    # Apply filters to determine eligible distributions
    eligible = eligible_distributions(anonymized_data)
    
    # Further limit to distributions set up for bidding
    eligible.select { |dist| dist.respond_to?(:bidding_enabled?) && dist.bidding_enabled? }
  end
  
  # Get all eligible entities (sources and distributions) for given lead data
  def eligible_entities(lead_data)
    FilterService.evaluate_filters(lead_data, self)
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
