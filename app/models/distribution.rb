class Distribution < ApplicationRecord
  acts_as_tenant :account

  belongs_to :company
  has_many :campaign_distributions, dependent: :destroy
  has_many :campaigns, through: :campaign_distributions
  has_many :headers, dependent: :destroy
  has_many :api_requests, as: :requestable, dependent: :destroy
  has_many :leads, through: :api_requests
  has_many :bids, dependent: :destroy

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

  def self.active
    where(status: :active)
  end

  def active?
    status == "active"
  end
  
  # Bidding attributes with defaults
  attribute :bidding_enabled, :boolean, default: true
  attribute :bidding_timeout_seconds, :integer, default: 5
  
  # Calculate bid amount for a lead based on its data
  def calculate_bid_amount(lead_data)
    # Simple implementation - in real application this would be more complex
    # and might include business rules or machine learning models
    base_bid_amount || 0.0
  end
end
