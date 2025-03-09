class Lead < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :campaign
  belongs_to :source, optional: true
  
  has_many :lead_data, class_name: "LeadData", dependent: :destroy
  has_many :api_requests, dependent: :destroy
  
  accepts_nested_attributes_for :lead_data
  
  validates :unique_id, presence: true, uniqueness: { scope: :account_id }
  
  before_validation :generate_unique_id, on: :create
  
  # Status enum for tracking lead lifecycle
  enum :status, {
    new_lead: 0,           # Just created, not yet processed
    processing: 10,   # Currently being processed
    distributed: 20,  # Successfully distributed to at least one endpoint
    rejected: 30,     # Rejected by all endpoints
    error: 40         # Error during processing
  }
  
  # Get a specific field value by campaign_field_id
  def field_value(campaign_field_id)
    lead_data.find_by(campaign_field_id: campaign_field_id)&.value
  end
  
  # Get all field values as a hash of field_name => value
  def field_values_hash
    result = {}
    lead_data.includes(:campaign_field).each do |data|
      result[data.campaign_field.name] = data.value if data.campaign_field.present?
    end
    result
  end
  
  # Execute validation rules on this lead
  def validate_against_rules
    errors = []
    campaign.validation_rules.active.order(:position).each do |rule|
      result = rule.test(self)
      errors << { rule: rule, message: result[:message] } unless result[:valid]
    end
    errors
  end
  
  # Check if lead passes all validation rules
  def valid_for_distribution?
    validate_against_rules.empty?
  end
  
  private
  
  def generate_unique_id
    self.unique_id ||= SecureRandom.uuid
  end
end