class Bid < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :bid_request
  belongs_to :distribution
  has_one :api_request, as: :requestable, dependent: :destroy
  
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
    bid_request.winning_bid == self
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
end