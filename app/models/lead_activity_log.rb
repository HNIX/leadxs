class LeadActivityLog < ApplicationRecord
  acts_as_tenant :account
  # Associations
  belongs_to :lead
  belongs_to :user, optional: true
  belongs_to :causer, polymorphic: true, optional: true

  # Enums
  enum :activity_type, {
    submission: 0,       # Initial submission
    validation: 1,       # Data validation 
    anonymization: 2,    # Data anonymization for bidding
    bid_request: 3,      # Bid request created
    bid_received: 4,     # Bid received from buyer
    bid_selected: 5,     # Winning bid selected
    consent_requested: 6, # Consent requested for specific buyer
    consent_provided: 7,  # Consent provided by lead
    distribution: 8,      # Lead distributed to buyer
    buyer_response: 9,    # Response received from buyer
    status_update: 10,    # Lead status update
    data_access: 11       # Someone accessed the lead data
  }

  # Additional tracking fields are:
  # - details: jsonb - contextual information about the activity
  # - ip_address: string - IP address of the user/system performing the action
  # - user_agent: string - User agent of the browser/system
  # - metadata: jsonb - additional context data
  # - timestamp: datetime - when the activity occurred
  
  # Callbacks
  after_create_commit :broadcast_to_activity_feed
  
  # Scopes
  scope :chronological, -> { order(created_at: :asc) }
  scope :recent_first, -> { order(created_at: :desc) }
  scope :for_lead, ->(lead_id) { where(lead_id: lead_id) }
  scope :with_type, ->(type) { where(activity_type: type) }
  scope :timeframe, ->(start_date, end_date) { 
    where("created_at >= ? AND created_at <= ?", start_date, end_date) if start_date.present? && end_date.present?
  }
  
  # Helps with tenant isolation
  acts_as_tenant :account
  
  # Instance methods
  def causer_info
    return nil unless causer
    
    {
      id: causer.id,
      type: causer_type,
      name: causer.respond_to?(:name) ? causer.name : causer.to_s
    }
  end

  # Class methods
  def self.record(lead, activity_type, details = {}, user = nil, request = nil)
    create(
      lead: lead,
      activity_type: activity_type,
      details: details,
      user: user,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent,
      causer: determine_causer(details),
      account_id: lead.account_id
    )
  end

  private

  def self.determine_causer(details)
    return nil unless details[:causer_type].present? && details[:causer_id].present?
    
    causer_type = details.delete(:causer_type)
    causer_id = details.delete(:causer_id)
    
    begin
      causer_type.constantize.find(causer_id)
    rescue
      nil
    end
  end
  
  def broadcast_to_activity_feed
    ActivityFeedBroadcastJob.perform_later(self, :activity)
  end
end