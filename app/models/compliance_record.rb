class ComplianceRecord < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :account
  belongs_to :record, polymorphic: true, optional: false
  belongs_to :user, class_name: "User", optional: true
  
  validates :action, :event_type, :occurred_at, presence: true
  
  before_validation :set_occurred_at
  
  # Event types for different compliance events
  LEAD_PROCESSING = "lead_processing"
  CONSENT = "consent"
  DISTRIBUTION = "distribution"
  DATA_ACCESS = "data_access"
  BID_REQUEST = "bid_request"
  BID_RESPONSE = "bid_response"
  VALIDATION = "validation"
  SYSTEM = "system"
  
  # Actions for different compliance activities
  CREATED = "created"
  UPDATED = "updated"
  DELETED = "deleted"
  ACCESS = "access"
  CONSENT_GIVEN = "consent_given"
  CONSENT_REJECTED = "consent_rejected"
  CONSENT_REVOKED = "consent_revoked"
  DISTRIBUTION_ATTEMPTED = "distribution_attempted"
  DISTRIBUTION_SUCCEEDED = "distribution_succeeded"
  DISTRIBUTION_FAILED = "distribution_failed"
  BID_REQUESTED = "bid_requested"
  BID_RECEIVED = "bid_received"
  VALIDATION_PASSED = "validation_passed"
  VALIDATION_FAILED = "validation_failed"
  
  # Scopes for filtering
  scope :lead_events, -> { where(record_type: 'Lead') }
  scope :distribution_events, -> { where(event_type: DISTRIBUTION) }
  scope :consent_events, -> { where(event_type: CONSENT) }
  scope :of_type, ->(type) { where(event_type: type) }
  scope :with_action, ->(action) { where(action: action) }
  scope :for_record, ->(record) { where(record_type: record.class.name, record_id: record.id) }
  scope :in_range, ->(start_date, end_date) { where(occurred_at: start_date..end_date) }
  
  # Class methods for creating common compliance events
  class << self
    # Create a compliance record for a lead event
    def record_lead_event(lead, action, data = {}, user = nil, request = nil)
      create_record(
        record: lead,
        event_type: LEAD_PROCESSING,
        action: action,
        data: data,
        user: user,
        request: request
      )
    end
    
    # Create a compliance record for a consent event
    def record_consent_event(consent_record, action, data = {}, user = nil, request = nil)
      create_record(
        record: consent_record,
        event_type: CONSENT,
        action: action,
        data: data,
        user: user,
        request: request
      )
    end
    
    # Create a compliance record for a distribution event
    def record_distribution_event(lead, distribution, action, data = {}, user = nil, request = nil)
      data = data.merge(distribution_id: distribution.id, distribution_name: distribution.name)
      
      create_record(
        record: lead,
        event_type: DISTRIBUTION,
        action: action,
        data: data,
        user: user,
        request: request
      )
    end
    
    # Create a compliance record for a validation event
    def record_validation_event(lead, action, data = {}, user = nil, request = nil)
      create_record(
        record: lead,
        event_type: VALIDATION,
        action: action,
        data: data,
        user: user,
        request: request
      )
    end
    
    # Create a compliance record for a bid event
    def record_bid_event(bid_request, action, data = {}, user = nil, request = nil)
      create_record(
        record: bid_request,
        event_type: BID_REQUEST,
        action: action,
        data: data,
        user: user,
        request: request
      )
    end
    
    # Create a generic compliance record
    def create_record(record:, event_type:, action:, data: {}, user: nil, request: nil)
      # Extract request info if provided
      ip_address = request&.ip || "0.0.0.0"
      user_agent = request&.user_agent || "Unknown"
      
      # Create the compliance record
      create!(
        record: record,
        event_type: event_type,
        action: action,
        data: data,
        user: user,
        ip_address: ip_address,
        user_agent: user_agent,
        occurred_at: Time.current
      )
    end
  end
  
  private
  
  def set_occurred_at
    self.occurred_at ||= Time.current
  end
end
