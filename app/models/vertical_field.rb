class VerticalField < ApplicationRecord
  acts_as_tenant :account
  acts_as_list scope: :vertical
  
  belongs_to :vertical
  has_many :campaign_fields, dependent: :destroy
  has_many :list_values, as: :list_owner, dependent: :destroy
  # Legacy: validation_rules will now be at the vertical level
  # has_many :validation_rules, as: :validatable, dependent: :destroy
  has_rich_text :notes
  
  # Define enums
  enum :data_type, { text: 0, number: 1, boolean: 2, date: 3, email: 5, phone: 6 }
  enum :value_acceptance, { any: 0, list: 1, range: 2 }
  
  validates :name, presence: true, uniqueness: { scope: :vertical_id }
  validates :data_type, presence: true
  validate :validate_list_values_if_list
  validate :validate_range_if_range
  
  accepts_nested_attributes_for :list_values, allow_destroy: true, reject_if: ->(attributes) { 
    # Reject if list_value is blank 
    attributes['list_value'].blank? 
  }
  
  # Broadcast changes in realtime with Hotwire
  after_create_commit -> { broadcast_prepend_later_to :vertical_fields, partial: "vertical_fields/index", locals: { vertical_field: self } }
  after_update_commit -> { broadcast_replace_later_to self }
  after_destroy_commit -> { broadcast_remove_to :vertical_fields, target: dom_id(self, :index) }
  
  # After creating a vertical field, create default validation rules based on data type
  # Disabled for test environment to avoid issues with unit tests
  after_create :create_default_validation_rules, unless: -> { Rails.env.test? }
  
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
    
    # Run all active validation rules
    results = validation_rules.active.ordered.map do |rule|
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
  
  # Clone validation rules from the vertical to a campaign
  def clone_validation_rules_to(campaign)
    # Get all validation rules from the vertical
    vertical.validation_rules.each do |rule|
      # Only clone rules that apply to this field
      next unless ValidationRule.applies_to_field?(rule, name)
      
      # Skip if a similar rule already exists for this field in the campaign
      existing_rule = campaign.validation_rules.find_by(name: "#{rule.name}: #{name}")
      next if existing_rule.present?
      
      # Convert vertical rule to a campaign rule
      campaign.validation_rules.create(
        rule_type: rule.rule_type,
        account: account,
        name: "#{rule.name}: #{name}",
        description: rule.description,
        condition: rule.condition,
        error_message: rule.error_message,
        severity: rule.severity,
        parameters: adapt_parameters_for_campaign(rule.parameters),
        position: rule.position,
        active: rule.active
      )
    end
    
    # Also create default field-specific rules (required fields, data type validations)
    create_field_specific_rules_for_campaign(campaign)
  end
  
  # Create specific rules for this field in the campaign
  def create_field_specific_rules_for_campaign(campaign)
    # Required field validation
    if required
      campaign.validation_rules.create(
        rule_type: ValidationRule::RULE_TYPES[:condition],
        account: account,
        name: "Required Field: #{name}",
        description: "Validates that #{name} is not empty",
        condition: "!String.empty?(field('#{name}'))",
        error_message: "#{label || name} is required",
        severity: ValidationRule::SEVERITIES[:error],
        active: true
      )
    end
    
    # Type-specific validations
    case data_type
    when 'email'
      campaign.validation_rules.create(
        rule_type: ValidationRule::RULE_TYPES[:pattern],
        account: account,
        name: "Valid Email Format: #{name}",
        description: "Ensures #{name} is a valid email address",
        condition: "true", # Placeholder
        error_message: "Please enter a valid email address for #{label || name}",
        severity: ValidationRule::SEVERITIES[:error],
        parameters: {
          'field_name' => name,
          'pattern' => '\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z'
        },
        active: true
      )
    when 'phone'
      campaign.validation_rules.create(
        rule_type: ValidationRule::RULE_TYPES[:pattern],
        account: account,
        name: "Valid Phone Format: #{name}",
        description: "Ensures #{name} is a valid phone number",
        condition: "true", # Placeholder
        error_message: "Please enter a valid phone number for #{label || name}",
        severity: ValidationRule::SEVERITIES[:error],
        parameters: {
          'field_name' => name,
          'pattern' => '\A\+?[1-9]\d{1,14}\z'
        },
        active: true
      )
    when 'number'
      # Add range validation if specified
      if value_acceptance == 'range' && min_value.present? && max_value.present?
        campaign.validation_rules.create(
          rule_type: ValidationRule::RULE_TYPES[:condition],
          account: account,
          name: "Number Range: #{name}",
          description: "Ensures #{name} is within the valid range",
          condition: "Number.between?(field('#{name}'), #{min_value}, #{max_value})",
          error_message: "#{label || name} must be between #{min_value} and #{max_value}",
          severity: ValidationRule::SEVERITIES[:error],
          active: true
        )
      end
    end
  end
  
  private
  
  # Adapt rule parameters to reference the campaign field correctly
  def adapt_parameters_for_campaign(parameters)
    adapted_params = parameters.dup
    
    # Update field_name references if present
    if adapted_params['field_name'].present?
      adapted_params['field_name'] = name
    end
    
    # Update primary_field and dependent_field references if present
    if adapted_params['primary_field'].present?
      adapted_params['primary_field'] = name if adapted_params['primary_field'] == name
    end
    
    if adapted_params['dependent_field'].present?
      adapted_params['dependent_field'] = name if adapted_params['dependent_field'] == name
    end
    
    # Update comparison_field references if present
    if adapted_params['comparison_field'].present?
      adapted_params['comparison_field'] = name if adapted_params['comparison_field'] == name
    end
    
    adapted_params
  end
  
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
  
  # Create default validation rules based on field data type
  def create_default_validation_rules
    # Skip if vertical is nil
    return unless vertical.present?
    
    case data_type
    when 'email'
      # Email format validation
      ValidationRule.create(
        rule_type: ValidationRule::RULE_TYPES[:pattern],
        account: account,
        validatable: vertical,
        name: "Valid Email Format",
        description: "Ensures the email address is in a valid format",
        condition: "true", # Placeholder, not used for pattern type
        error_message: "Please enter a valid email address",
        severity: ValidationRule::SEVERITIES[:error],
        parameters: {
          'field_name' => name,
          'pattern' => '\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z'
        },
        position: 0,
        active: true
      )
    when 'phone'
      # Phone format validation
      ValidationRule.create(
        rule_type: ValidationRule::RULE_TYPES[:pattern],
        account: account,
        validatable: vertical,
        name: "Valid Phone Format",
        description: "Ensures the phone number is in E.164 format",
        condition: "true", # Placeholder, not used for pattern type
        error_message: "Please enter a valid phone number",
        severity: ValidationRule::SEVERITIES[:error],
        parameters: {
          'field_name' => name,
          'pattern' => '\A\+?[1-9]\d{1,14}\z'
        },
        position: 0,
        active: true
      )
    end
  end
end