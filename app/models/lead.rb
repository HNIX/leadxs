class Lead < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :campaign
  belongs_to :source, optional: true
  belongs_to :bid_request, optional: true
  
  has_many :lead_data, class_name: "LeadData", dependent: :destroy
  has_many :api_requests, dependent: :destroy
  has_one :generated_bid_request, class_name: "BidRequest", foreign_key: "lead_id", dependent: :nullify
  
  accepts_nested_attributes_for :lead_data
  
  validates :unique_id, presence: true, uniqueness: { scope: :account_id }
  
  before_validation :generate_unique_id, on: :create
  
  # Status enum for tracking lead lifecycle
  enum :status, {
    new_lead: 0,      # Just created, not yet processed
    processing: 10,   # Currently being processed
    distributing: 15, # Currently being distributed to endpoints
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
    validation_failures = {}
    
    campaign.validation_rules.active.ordered.each do |rule|
      result = ValidationRuleProcessor.new(rule, field_values_hash, self).evaluate
      
      unless result.valid?
        validation_failures[rule.id] = {
          rule_name: rule.name,
          message: result.message,
          severity: result.severity
        }
      end
    end
    
    validation_failures
  end
  
  # Check if lead passes all validation rules
  def valid_for_distribution?
    failures = validate_against_rules
    
    # Lead is valid if there are no errors (warnings and info are allowed)
    !failures.any? { |_, failure| failure[:severity] == 'error' }
  end
  
  # Check if lead passes all critical validation rules
  def valid_for_processing?
    validate_against_rules.empty?
  end
  
  # Get anonymized data for bidding purposes
  def anonymized_data
    result = {}
    campaign.campaign_fields.each do |field|
      # Skip fields not marked for sharing during bidding
      next unless field.share_during_bidding?
      
      # Get the field value
      value = field_value(field.id)
      next if value.blank?
      
      if field.pii?
        # Apply PII anonymization based on field type
        result[field.name] = anonymize_field_value(field, value)
      else
        # Include non-PII fields as is
        result[field.name] = value
      end
    end
    
    # Add metadata about the lead that's safe to share
    result['lead_id'] = unique_id
    result['submission_timestamp'] = created_at.iso8601
    result['source_type'] = source&.integration_type
    
    # Add calculated fields marked for bidding
    campaign.calculated_fields.each do |calc_field|
      next unless calc_field.share_during_bidding?
      
      # The calculated field value should already be stored in lead_data
      value = field_value(calc_field.id)
      result[calc_field.name] = value if value.present?
    end
    
    result
  end
  
  private
  
  # Anonymize a field value based on its type and sensitivity
  def anonymize_field_value(field, value)
    return nil if value.blank?
    
    case field.field_type
    when 'email'
      anonymize_email(value)
    when 'phone'
      anonymize_phone(value)
    when 'name', 'first_name', 'last_name'
      anonymize_name(value)
    when 'address', 'street'
      anonymize_address(value)
    when 'ssn', 'social_security'
      # Never share SSN, even anonymized
      nil
    when 'credit_card'
      # Never share credit card, even anonymized
      nil
    when 'zip'
      # For zip codes, we can share the first 3 digits (not considered PII)
      value.to_s[0..2] + 'XX'
    when 'date_of_birth', 'dob'
      # For DOB, only share year or age range
      begin
        date = Date.parse(value.to_s)
        "#{Date.today.year - date.year} years old"
      rescue
        "Unknown age"
      end
    else
      # For other PII fields, use generic placeholders
      "[REDACTED]"
    end
  end
  
  # Anonymize email address
  def anonymize_email(email)
    return nil unless email.present? && email.include?('@')
    
    # Split the email into local part and domain
    local, domain = email.split('@', 2)
    
    # Anonymize the local part but leave the domain (domains aren't PII)
    # Show first character, hide the rest
    if local.length > 2
      "#{local[0]}#{'*' * (local.length - 1)}@#{domain}"
    else
      "***@#{domain}"
    end
  end
  
  # Anonymize phone number
  def anonymize_phone(phone)
    phone = phone.to_s.gsub(/\D/, '')
    
    # Keep the area code if US number, hide the rest
    if phone.length >= 10
      "#{phone[0..2]}-***-****"
    else
      # For non-standard numbers, just return the first 3 digits
      "#{phone[0..2]}-****"
    end
  end
  
  # Anonymize name - just show initial
  def anonymize_name(name)
    return nil unless name.present?
    
    # Just show the first initial
    "#{name[0]}."
  end
  
  # Anonymize address
  def anonymize_address(address)
    return nil unless address.present?
    
    # For addresses, we can share general location without specific address
    parts = address.split(' ', 2)
    
    if parts.length > 1
      # Hide the street number, keep the street name
      "#### #{parts[1]}"
    else
      "#### Street"
    end
  end
  
  private
  
  def generate_unique_id
    self.unique_id ||= SecureRandom.uuid
  end
end