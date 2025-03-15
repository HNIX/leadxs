class BidRequest < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :campaign
  belongs_to :lead, optional: true
  has_many :bids, dependent: :destroy
  
  store_accessor :anonymized_data, []
  store_accessor :bid_metadata, []
  
  enum :status, {
    pending: 0,
    active: 10,
    completed: 20,
    expired: 30,
    canceled: 40
  }
  
  validates :unique_id, presence: true, uniqueness: { scope: :account_id }
  
  # Make sure expires_at is not initialized with a default value
  attribute :expires_at, :datetime, default: nil
  validates :expires_at, presence: true
  
  before_validation :generate_unique_id, on: :create
  before_validation :set_expiration, on: :create
  
  scope :active, -> { where(status: :active) }
  scope :pending, -> { where(status: :pending) }
  scope :expired, -> { where(status: :expired) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Get winning bid based on campaign distribution method
  def winning_bid
    return nil if bids.empty?
    
    case campaign.distribution_method
    when 'highest_bid'
      bids.order(amount: :desc).first
    when 'weighted_random'
      # Implement weighted random selection based on bid amounts
      total_amount = bids.sum(:amount)
      return bids.first if total_amount == 0
      
      random_point = rand * total_amount
      current_sum = 0
      
      bids.each do |bid|
        current_sum += bid.amount
        return bid if current_sum >= random_point
      end
      
      bids.first # Fallback
    else
      bids.order(amount: :desc).first # Default to highest bid
    end
  end
  
  # Check if bid request has expired
  def expired?
    expires_at <= Time.current || status == 'expired'
  end
  
  # Check if bid request is completed
  def completed?
    status == 'completed'
  end
  
  # Mark as expired if time has passed
  # Returns true if the request was expired during this check
  def check_expiration!
    if expires_at <= Time.current && status.in?(['active', 'pending'])
      update(status: :expired)
      Rails.logger.info("BidRequest ##{id} marked as expired (was: #{status_was}, expired at: #{expires_at})")
      return true
    end
    false
  end
  
  # Check if request is technically expired by time but not yet marked as expired
  def technically_expired?
    expires_at <= Time.current && status.in?(['active', 'pending'])
  end
  
  # Get field values from lead if present
  def field_values_hash
    return anonymized_data if lead.nil?
    lead.field_values_hash
  end
  
  # Complete the bidding process and distribute the lead
  def complete_bidding_and_distribute!
    return false if expired? || status != 'active' || lead.nil?
    
    # Get the winning bid
    winning = winning_bid
    return false if winning.nil?
    
    # Accept the winning bid
    return false unless winning.accept!
    
    # Update the bid request status and set completed_at timestamp
    update(status: :completed, completed_at: Time.current)
    
    # Now distribute the lead to the winning distribution
    distribute_lead_to_winning_bid(winning)
    
    true
  end
  
  # Distribute the lead to the winning distribution(s)
  def distribute_lead_to_winning_bid(winning_bid)
    return false if lead.nil?
    
    # Update lead status to distributing
    lead.update(status: :distributing)
    
    # Find the campaign distribution for the winning bid
    primary_distribution = campaign.campaign_distributions.find_by(distribution: winning_bid.distribution)
    return false unless primary_distribution
    
    # Check if campaign is configured for multi-distribution
    if campaign.multi_distribution_strategy == "single" || campaign.max_distributions <= 1
      # Use LeadDistributionService for a single distribution
      distribution_service = LeadDistributionService.new(lead)
      
      # Set the bid_request_id to indicate this is the post phase of ping-post
      # This ensures correct endpoint URL selection
      lead.update(bid_request_id: id) if lead.bid_request_id.nil?
      
      result = distribution_service.distribute_to_specific!(primary_distribution)
      
      # Update lead status based on distribution result
      if result[:success]
        lead.update(status: :distributed)
      else
        lead.update(status: :error, error_message: result[:error])
      end
      
      result[:success]
    else
      # Use MultiDistributionService for multi-distribution strategies
      
      # Set the bid_request_id to indicate this is the post phase of ping-post
      lead.update(bid_request_id: id) if lead.bid_request_id.nil?
      
      # For multi-distribution, we need a list of winning distributions
      # In some cases, we might have multiple winning bids (for parallel strategy)
      winning_distributions = []
      
      # Add primary distribution first
      winning_distributions << primary_distribution
      
      # Get additional distributions based on strategy
      case campaign.multi_distribution_strategy
      when "parallel"
        # For parallel, we might get multiple high bids (top N by amount)
        max_additional = (campaign.max_distributions || 1) - 1
        if max_additional > 0
          # Get additional top bids excluding the winning one
          additional_bids = bids.where.not(id: winning_bid.id)
                               .order(amount: :desc)
                               .limit(max_additional)
          
          # Add their distributions
          additional_bids.each do |bid|
            dist = campaign.campaign_distributions.find_by(distribution: bid.distribution)
            winning_distributions << dist if dist && dist.active?
          end
        end
      when "sequential"
        # Leave as is - just use the primary winning distribution
      end
      
      # Create the distribution service 
      distribution_service = MultiDistributionService.new(lead)
      
      # Distribute to winning distributions
      result = distribution_service.distribute_to_winners(winning_distributions)
      
      result[:success]
    end
  end
  
  private
  
  def generate_unique_id
    self.unique_id ||= SecureRandom.uuid
  end
  
  def set_expiration
    # If campaign has bid_timeout_seconds set, use that; otherwise use 2 minutes as default
    # This ensures we have a reasonable default even if campaign config is missing
    if campaign && campaign.bid_timeout_seconds.present?
      self.expires_at ||= Time.current + campaign.bid_timeout_seconds.seconds
    else
      self.expires_at ||= 2.minutes.from_now
    end
  end
end