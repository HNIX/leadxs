class ConsentRecord < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :account
  belongs_to :lead
  belongs_to :user, class_name: "User", optional: true
  
  has_many :compliance_records, as: :record, dependent: :destroy
  
  # Types of consent that can be recorded
  DISTRIBUTION_CONSENT = "distribution_consent"
  MARKETING_CONSENT = "marketing_consent"
  TERMS_OF_SERVICE = "terms_of_service"
  PRIVACY_POLICY = "privacy_policy"
  DATA_SHARING = "data_sharing"
  
  validates :consent_type, :consent_text, :ip_address, :consented_at, presence: true
  validates :uuid, uniqueness: true
  
  # Validate proof token format if present
  validate :validate_proof_token, if: -> { proof_token.present? }
  
  before_validation :set_consented_at
  before_create :generate_proof_token
  after_create :create_compliance_record
  
  # Scopes
  scope :active, -> { where(revoked: false) }
  scope :revoked, -> { where(revoked: true) }
  scope :of_type, ->(type) { where(consent_type: type) }
  scope :expired, -> { where("expires_at IS NOT NULL AND expires_at < ?", Time.current) }
  scope :valid_at, ->(time) { 
    where("consented_at <= ? AND (expires_at IS NULL OR expires_at > ?) AND revoked = false", time, time) 
  }
  
  # Check if the consent is active (not revoked and not expired)
  def active?
    !revoked? && (!expires_at.present? || expires_at > Time.current)
  end
  
  # Revoke the consent
  def revoke!(reason = nil)
    return false if revoked?
    
    update(
      revoked: true,
      revoked_at: Time.current,
      revocation_reason: reason
    )
    
    # Log the revocation
    ComplianceRecord.record_consent_event(
      self,
      ComplianceRecord::CONSENT_REVOKED,
      { reason: reason },
      Current.user,
      Current.request
    )
    
    true
  end
  
  # Extend the expiration date
  def extend_expiration!(new_expiry_date)
    return false unless new_expiry_date > Time.current
    return false if revoked?
    
    previous_expiry = expires_at
    update(expires_at: new_expiry_date)
    
    # Log the extension
    ComplianceRecord.record_consent_event(
      self,
      ComplianceRecord::UPDATED,
      { 
        previous_expiry: previous_expiry&.iso8601,
        new_expiry: new_expiry_date.iso8601,
        action: "extend_expiration"
      },
      Current.user,
      Current.request
    )
    
    true
  end
  
  # Generate a signed consent receipt using JWT
  def generate_consent_receipt
    payload = {
      uuid: uuid,
      lead_id: lead.unique_id,
      consent_type: consent_type,
      consented_at: consented_at.iso8601,
      ip_address: ip_address,
      user_agent: user_agent,
      campaign_id: lead.campaign_id,
      expires_at: expires_at&.iso8601
    }
    
    # Generate a JWT token that can be verified later
    secret = Rails.application.credentials.secret_key_base
    JWT.encode(payload, secret, 'HS256')
  end
  
  # Verify a consent receipt JWT
  def self.verify_consent_receipt(token)
    secret = Rails.application.credentials.secret_key_base
    
    begin
      decoded = JWT.decode(token, secret, true, { algorithm: 'HS256' })
      payload = decoded.first
      
      # Find the consent record by UUID
      consent = find_by(uuid: payload['uuid'])
      return nil unless consent.present?
      
      # Verify that the consent record matches the payload
      return nil unless consent.lead.unique_id == payload['lead_id']
      return nil unless consent.consent_type == payload['consent_type']
      return nil unless consent.consented_at.iso8601 == payload['consented_at']
      
      # Return the consent record if everything matches
      consent
    rescue JWT::DecodeError
      nil
    end
  end
  
  # Override to_param to use UUID in URLs
  def to_param
    uuid
  end
  
  private
  
  def set_consented_at
    self.consented_at ||= Time.current
  end
  
  def generate_proof_token
    self.proof_token ||= SecureRandom.hex(16)
  end
  
  def create_compliance_record
    ComplianceRecord.record_consent_event(
      self,
      ComplianceRecord::CONSENT_GIVEN,
      {
        lead_id: lead.id,
        lead_unique_id: lead.unique_id,
        consent_type: consent_type,
        expires_at: expires_at&.iso8601
      },
      user,
      Current.request
    )
  end
  
  def validate_proof_token
    errors.add(:proof_token, "is invalid") unless proof_token.match?(/\A[a-f0-9]{32}\z/i)
  end
end
