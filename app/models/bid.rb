class Bid < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :bid_request
  belongs_to :distribution
  has_one :api_request, as: :requestable, dependent: :destroy
  
  after_create :broadcast_new_bid
  after_update :broadcast_status_change, if: -> { saved_change_to_status? }
  
  enum :status, {
    pending: 0,
    accepted: 10,
    rejected: 20,
    expired: 30,
    error: 40
  }
  
  # Make sure amount is not initialized with a default value
  attribute :amount, :decimal, default: nil
  
  validates :amount, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, if: -> { amount.present? }
  validates :distribution_id, uniqueness: { scope: :bid_request_id, message: "has already placed a bid" }
  
  scope :pending, -> { where(status: :pending) }
  scope :accepted, -> { where(status: :accepted) }
  scope :highest_first, -> { order(amount: :desc) }
  
  # Check if this bid is the winner of its bid request
  def winning_bid?
    return false unless bid_request.present?
    return accepted? if bid_request.status == 'completed'
    
    # If there's a specific method to determine the winning bid
    bid_request.respond_to?(:winning_bid) ? (bid_request.winning_bid == self) : false
  end
  
  # Accept this bid - usually called when a lead is being finalized
  def accept!
    return false if bid_request.expired?
    
    transaction do
      update!(status: :accepted)
      bid_request.bids.where.not(id: id).update_all(status: :rejected)
      bid_request.update!(status: :completed)
      true
    end
  end
  
  # Mark as expired
  def expire!
    update!(status: :expired) unless accepted?
  end
  
  # Helper method to get campaign through bid request
  def campaign
    bid_request&.campaign
  end
  
  private
  
  # Broadcast new bid to the real-time dashboard
  def broadcast_new_bid
    BidAnalyticsBroadcastJob.perform_later(account_id, :new_bid, self)
    ActivityFeedBroadcastJob.perform_later(self, :bid)
  end
  
  # Broadcast status change to the real-time dashboard
  def broadcast_status_change
    BidAnalyticsBroadcastJob.perform_later(account_id, :new_bid, self)
    ActivityFeedBroadcastJob.perform_later(self, :bid)
  end
end