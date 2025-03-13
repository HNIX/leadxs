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
  def check_expiration!
    update(status: :expired) if expires_at <= Time.current && status == 'active'
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
      # The winning bid already determined which distributions to use
      distribution_service = MultiDistributionService.new(lead)
      
      # The service handles updating the lead status
      result = distribution_service.distribute!
      
      result[:success]
    end
  end
  
  private
  
  def generate_unique_id
    self.unique_id ||= SecureRandom.uuid
  end
  
  def set_expiration
    self.expires_at ||= 5.minutes.from_now
  end
end