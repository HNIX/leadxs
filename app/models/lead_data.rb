class LeadData < ApplicationRecord
  belongs_to :lead
  belongs_to :campaign_field
  
  validates :campaign_field_id, uniqueness: { scope: :lead_id }
  
  # Validate the value based on the field type
  validate :validate_field_value
  
  private
  
  def validate_field_value
    return unless campaign_field.present? && value.present?
    
    case campaign_field.field_type
    when 'number'
      errors.add(:value, "must be a number") unless value.to_s =~ /\A[+-]?\d+(\.\d+)?\z/
    when 'email'
      errors.add(:value, "must be a valid email") unless value =~ /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    when 'phone'
      # Basic phone validation - should match E164 or be at least 10 digits
      errors.add(:value, "must be a valid phone number") unless value.gsub(/\D/, '').length >= 10
    when 'date'
      begin
        Date.parse(value.to_s)
      rescue ArgumentError
        errors.add(:value, "must be a valid date")
      end
    when 'boolean'
      unless ['true', 'false', '1', '0', 'yes', 'no', 'y', 'n'].include?(value.to_s.downcase)
        errors.add(:value, "must be a boolean value")
      end
    when 'list'
      # Check if value is in the allowed list values
      list_values = campaign_field.list_values.map(&:value)
      errors.add(:value, "is not a valid option") unless list_values.include?(value)
    end
  end
end