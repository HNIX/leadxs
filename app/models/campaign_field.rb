class CampaignField < ApplicationRecord
  acts_as_tenant :account
  acts_as_list scope: :campaign
  
  belongs_to :campaign
  belongs_to :vertical_field, optional: true
  has_many :list_values, as: :list_owner, dependent: :destroy
  # We're moving validation rules to the campaign level
  # Legacy validation rules will still use the polymorphic association
  has_rich_text :notes
  
  # Define enums - match VerticalField
  enum :data_type, { text: 0, number: 1, boolean: 2, date: 3, email: 5, phone: 6 }
  enum :value_acceptance, { any: 0, list: 1, range: 2 }
  
  # Whether this field contains PII (Personally Identifiable Information)
  attribute :pii, :boolean, default: false
  
  # Whether this field can be used in anonymous bidding process
  attribute :anonymous_bidding_enabled, :boolean, default: false
  
  # Whether this field should be shared during the bidding phase
  attribute :share_during_bidding, :boolean, default: false
  
  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { scope: [:account_id, :campaign_id], message: "already exists in this campaign" }
  validate :validate_list_values_if_list
  validate :validate_range_if_range
  validates :data_type, presence: true
  
  # After creation, inherit validation rules from vertical field
  after_create :inherit_validation_rules
  
  # Handle options as array for backwards compatibility
  def options
    self[:options].present? ? JSON.parse(self[:options]) : []
  end
  
  def options=(value)
    self[:options] = value.is_a?(Array) ? value.to_json : value
  end
  
  accepts_nested_attributes_for :list_values, allow_destroy: true, reject_if: ->(attributes) { 
    # Reject if list_value is blank 
    attributes['list_value'].blank? 
  }
  
  # Scopes
  scope :ordered, -> { order(position: :asc) }
  scope :required_fields, -> { where(required: true) }
  scope :ping_fields, -> { where(ping_required: true) }
  scope :post_fields, -> { where(post_required: true) }
  scope :visible_fields, -> { where(hide: false) }
  
  # Methods to check field type (for backward compatibility)
  def text?
    data_type == 'text' || field_type == 'text'
  end
  
  def number?
    data_type == 'number' || field_type == 'number'
  end
  
  def date?
    data_type == 'date' || field_type == 'date' || field_type == 'datetime'
  end
  
  def email?
    data_type == 'email' || field_type == 'email'
  end
  
  def phone?
    data_type == 'phone' || field_type == 'phone'
  end
  
  def boolean?
    data_type == 'boolean'
  end
  
  # Determine if this field should be shared during bidding
  def share_during_bidding?
    # Explicit setting takes precedence
    return share_during_bidding if share_during_bidding.present?
    
    # Legacy support for anonymous_bidding_enabled
    return anonymous_bidding_enabled if anonymous_bidding_enabled.present?
    
    # Default behavior based on field properties
    
    # Never share certain field types during bidding regardless of PII status
    return false if %w[ssn social_security credit_card password].include?(field_type)
    
    # For PII fields, don't share unless explicitly configured to
    return false if pii?
    
    # Share non-PII fields by default, especially useful ones for bidding
    return true if %w[zip state city income age].include?(name.downcase)
    
    # Default to not sharing unless explicitly enabled
    false
  end
  
  
  def generate_example_value
    case data_type
    when 'text'
      "Sample Text"
    when 'number'
      min_value.present? && max_value.present? ? ((min_value.to_f + max_value.to_f) / 2).round(2) : 42
    when 'boolean'
      true
    when 'date'
      Date.today.to_s
    when 'email'
      "example@email.com"
    when 'phone'
      "+1234567890"
    else
      "Example value"
    end
  end
  
  def format_description
    case data_type
    when 'text'
      value_acceptance == 'list' ? "One of: #{list_values.pluck(:list_value).join(', ')}" : "Any text"
    when 'number'
      value_acceptance == 'range' ? "Number between #{min_value} and #{max_value}" : 
        (value_acceptance == 'list' ? "One of: #{list_values.pluck(:list_value).join(', ')}" : "Any number")
    when 'boolean'
      "true or false"
    when 'date'
      "YYYY-MM-DD"
    when 'email'
      "Valid email address"
    when 'phone'
      "E.164 format phone number"
    else
      "Format varies"
    end
  end
  
  # Validate a value against all active validation rules
  def validate_value(value, data = {})
    # Start with built-in validations based on field type
    validation_result = validate_by_field_type(value)
    return validation_result unless validation_result[:valid]
    
    # If built-in validation passes, check custom validation rules
    # Prepare data hash with this field's value and any additional data
    validation_data = data.merge({ name => value })
    
    # Get all rules that apply to this field
    # First, try to find legacy rules associated directly with this field
    legacy_rules = ValidationRule.where(validatable_id: id, validatable_type: 'CampaignField').active.ordered
    
    # Then, get campaign-level rules that reference this field
    campaign_rules = ValidationRule.for_field(name, campaign)
    
    # Combine both sets of rules
    all_rules = legacy_rules + campaign_rules
    
    # Run all active validation rules
    results = all_rules.map do |rule|
      rule.evaluate(validation_data)
    end
    
    # Find the first failing rule (if any)
    failing_result = results.find { |result| !result[:valid] }
    
    if failing_result
      failing_result
    else
      { valid: true, rule_id: nil, rule_name: nil, error_message: nil, severity: nil }
    end
  end
  
  # Add a new validation rule to the campaign for this field
  def add_validation_rule(rule_type, name, condition, error_message, severity = 'error', parameters = {})
    campaign.validation_rules.create(
      rule_type: rule_type,
      account: account,
      name: name,
      condition: condition,
      error_message: error_message,
      severity: severity,
      parameters: parameters,
      active: true
    )
  end
  
  private
  
  def validate_list_values_if_list
    if value_acceptance == 'list' && list_values.reject(&:marked_for_destruction?).empty?
      errors.add(:list_values, "must be provided when value acceptance is set to list")
    end
  end
  
  def validate_range_if_range
    if value_acceptance == 'range' && (min_value.blank? || max_value.blank?)
      errors.add(:min_value, "must be provided when value acceptance is set to range") if min_value.blank?
      errors.add(:max_value, "must be provided when value acceptance is set to range") if max_value.blank?
    end
  end
  
  # Inherit validation rules from vertical field
  def inherit_validation_rules
    return unless vertical_field.present?
    
    vertical_field.clone_validation_rules_to(campaign)
    
    # Add additional validation rules based on campaign field properties
    create_default_validation_rules
  end
  
  # Create default validation rules based on field properties
  def create_default_validation_rules
    # Check if validation rules already exist for this field in the campaign
    campaign_rules = ValidationRule.for_field(name, campaign)
    
    # Required field validation
    if required
      rule_name = "Required Field: #{name}"
      
      # Only add if a similar rule doesn't exist
      unless campaign_rules.any? { |r| r.name == rule_name }
        add_validation_rule(
          ValidationRule::RULE_TYPES[:condition],
          rule_name,
          "!String.empty?(field('#{name}'))",
          "#{label || name} is required",
          ValidationRule::SEVERITIES[:error]
        )
      end
    end
    
    # Add type-specific validations
    case data_type
    when 'email'
      rule_name = "Valid Email Format: #{name}"
      
      # Only add if no validation rule exists for email format
      unless campaign_rules.any? { |r| r.name == rule_name }
        add_validation_rule(
          ValidationRule::RULE_TYPES[:pattern],
          rule_name,
          "true", # Placeholder, not used for pattern type
          "Please enter a valid email address",
          ValidationRule::SEVERITIES[:error],
          {
            'field_name' => name,
            'pattern' => '\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z'
          }
        )
      end
    when 'phone'
      rule_name = "Valid Phone Format: #{name}"
      
      # Only add if no validation rule exists for phone format
      unless campaign_rules.any? { |r| r.name == rule_name }
        add_validation_rule(
          ValidationRule::RULE_TYPES[:pattern],
          rule_name,
          "true", # Placeholder, not used for pattern type
          "Please enter a valid phone number",
          ValidationRule::SEVERITIES[:error],
          {
            'field_name' => name,
            'pattern' => '\A\+?[1-9]\d{1,14}\z'
          }
        )
      end
    when 'number'
      # Add range validation if specified
      if value_acceptance == 'range' && min_value.present? && max_value.present?
        rule_name = "Number Range: #{name}"
        
        # Only add if no similar rule exists
        unless campaign_rules.any? { |r| r.name == rule_name }
          add_validation_rule(
            ValidationRule::RULE_TYPES[:condition],
            rule_name,
            "Number.between?(field('#{name}'), #{min_value}, #{max_value})",
            "#{label || name} must be between #{min_value} and #{max_value}",
            ValidationRule::SEVERITIES[:error]
          )
        end
      end
    end
  end
  
  # Built-in validations based on field type
  def validate_by_field_type(value)
    # Skip validation if value is blank and field is not required
    return { valid: true } if value.blank? && !required
    
    # Validate based on data type
    case data_type
    when 'text'
      validate_text(value)
    when 'number'
      validate_number(value)
    when 'boolean'
      validate_boolean(value)
    when 'date'
      validate_date(value)
    when 'email'
      validate_email(value)
    when 'phone'
      validate_phone(value)
    else
      { valid: true }
    end
  end
  
  def validate_text(value)
    # Skip validation if value is nil
    return { valid: true } if value.nil?
    
    # Value must be a string
    unless value.is_a?(String)
      return { 
        valid: false, 
        error_message: "Value must be a string",
        severity: "error"
      }
    end
    
    # Check min/max length if specified
    if min_length.present? && value.length < min_length
      return { 
        valid: false, 
        error_message: "Value must be at least #{min_length} characters",
        severity: "error"
      }
    end
    
    if max_length.present? && value.length > max_length
      return { 
        valid: false, 
        error_message: "Value must be no more than #{max_length} characters",
        severity: "error"
      }
    end
    
    # Check regex pattern if specified
    if validation_regex.present?
      unless value.match?(Regexp.new(validation_regex))
        return { 
          valid: false, 
          error_message: "Value does not match the required pattern",
          severity: "error"
        }
      end
    end
    
    # Check list values if value_acceptance is 'list'
    if value_acceptance == 'list'
      allowed_values = list_values.pluck(:list_value)
      unless allowed_values.include?(value)
        return { 
          valid: false, 
          error_message: "Value must be one of: #{allowed_values.join(', ')}",
          severity: "error"
        }
      end
    end
    
    { valid: true }
  end
  
  def validate_number(value)
    # Skip validation if value is nil
    return { valid: true } if value.nil?
    
    # Convert value to number
    begin
      num_value = Float(value)
    rescue ArgumentError, TypeError
      return { 
        valid: false, 
        error_message: "Value must be a number",
        severity: "error"
      }
    end
    
    # Check range if value_acceptance is 'range'
    if value_acceptance == 'range'
      if min_value.present? && num_value < min_value.to_f
        return { 
          valid: false, 
          error_message: "Value must be at least #{min_value}",
          severity: "error"
        }
      end
      
      if max_value.present? && num_value > max_value.to_f
        return { 
          valid: false, 
          error_message: "Value must be no more than #{max_value}",
          severity: "error"
        }
      end
    end
    
    # Check list values if value_acceptance is 'list'
    if value_acceptance == 'list'
      allowed_values = list_values.pluck(:list_value).map(&:to_f)
      unless allowed_values.include?(num_value)
        return { 
          valid: false, 
          error_message: "Value must be one of: #{list_values.pluck(:list_value).join(', ')}",
          severity: "error"
        }
      end
    end
    
    { valid: true }
  end
  
  def validate_boolean(value)
    # Skip validation if value is nil
    return { valid: true } if value.nil?
    
    # Value must be a boolean or convertible to boolean
    unless [true, false, 1, 0, '1', '0', 'true', 'false', 'yes', 'no'].include?(value.to_s.downcase)
      return { 
        valid: false, 
        error_message: "Value must be true or false",
        severity: "error"
      }
    end
    
    { valid: true }
  end
  
  def validate_date(value)
    # Skip validation if value is nil
    return { valid: true } if value.nil?
    
    # Try to parse as date
    begin
      date_value = value.is_a?(Date) ? value : Date.parse(value.to_s)
    rescue ArgumentError
      return { 
        valid: false, 
        error_message: "Value must be a valid date (YYYY-MM-DD)",
        severity: "error"
      }
    end
    
    { valid: true }
  end
  
  def validate_email(value)
    # Skip validation if value is nil
    return { valid: true } if value.nil?
    
    # Basic email validation
    email_regex = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    unless value.to_s.match?(email_regex)
      return { 
        valid: false, 
        error_message: "Value must be a valid email address",
        severity: "error"
      }
    end
    
    { valid: true }
  end
  
  def validate_phone(value)
    # Skip validation if value is nil
    return { valid: true } if value.nil?
    
    # Basic phone validation (E.164 format)
    phone_regex = /\A\+?[1-9]\d{1,14}\z/
    unless value.to_s.match?(phone_regex)
      return { 
        valid: false, 
        error_message: "Value must be a valid phone number in E.164 format",
        severity: "error"
      }
    end
    
    { valid: true }
  end
end
