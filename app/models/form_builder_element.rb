class FormBuilderElement < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :form_builder
  belongs_to :campaign_field, optional: true
  
  # Initialize properties as empty hash if nil
  before_validation :ensure_properties_initialized
  
  def ensure_properties_initialized
    self.properties ||= {}
  end
  
  # Element types that can be used in the form
  ELEMENT_TYPES = %w[
    text textarea number email phone password date time datetime 
    select checkbox radio file upload address
    header paragraph divider image consent submit
    multi_step grid row column
  ].freeze
  
  validates :element_type, presence: true, inclusion: { in: ELEMENT_TYPES }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  
  # Returns true if this element has conditional display logic
  def conditional_display?
    display_condition_element_id.present? && 
    display_condition_operator.present? && 
    display_condition_value.present?
  end
  
  # Returns true if this element is a container that can have child elements
  def container?
    %w[multi_step grid row column].include?(element_type)
  end
  
  # Returns true if this element is a form input that collects data
  def input?
    !%w[header paragraph divider image submit].include?(element_type)
  end
  
  # Gets the field name to use for form submission
  def field_name
    return "element_#{id}" unless campaign_field
    campaign_field.name
  end
  
  # Gets the validation rules for this element based on the campaign field
  def validation_rules
    return {} unless campaign_field
    
    rules = {}
    
    # Add basic validation based on field properties
    rules[:required] = true if campaign_field.required?
    
    if campaign_field.data_type == 'text'
      rules[:min_length] = campaign_field.min_length if campaign_field.min_length
      rules[:max_length] = campaign_field.max_length if campaign_field.max_length
    end
    
    if campaign_field.data_type == 'number'
      rules[:min] = campaign_field.min_value if campaign_field.min_value
      rules[:max] = campaign_field.max_value if campaign_field.max_value
    end
    
    # Add regex validation if present
    if campaign_field.validation_regex.present?
      rules[:pattern] = campaign_field.validation_regex
    end
    
    # Add field type specific validation
    case campaign_field.data_type
    when 'email'
      rules[:email] = true
    when 'phone'
      rules[:phone] = true
    when 'date'
      rules[:date] = true
    end
    
    # Add list validation if field is list-based
    if campaign_field.value_acceptance == 'list'
      rules[:options] = campaign_field.list_values.pluck(:value)
    end
    
    rules
  end
  
  # Gets the choices for select, radio, or checkbox elements
  def choices
    return [] unless campaign_field&.value_acceptance == 'list'
    
    campaign_field.list_values.map do |list_value|
      {
        value: list_value.value,
        label: list_value.label.presence || list_value.value,
        disabled: !list_value.active
      }
    end
  end
  
  # Generates client-side validation rules in a format suitable for JavaScript validation
  def client_validation_json
    rules = validation_rules
    return {} if rules.empty?
    
    # Convert validation rules to a format suitable for client-side validation
    client_rules = {}
    
    client_rules[:required] = rules[:required] if rules[:required]
    client_rules[:minLength] = rules[:min_length] if rules[:min_length]
    client_rules[:maxLength] = rules[:max_length] if rules[:max_length]
    client_rules[:min] = rules[:min] if rules[:min]
    client_rules[:max] = rules[:max] if rules[:max]
    client_rules[:pattern] = rules[:pattern] if rules[:pattern]
    client_rules[:email] = rules[:email] if rules[:email]
    client_rules[:phone] = rules[:phone] if rules[:phone]
    client_rules[:date] = rules[:date] if rules[:date]
    client_rules[:options] = rules[:options] if rules[:options]
    
    # Add error messages
    client_rules[:messages] = {
      required: "This field is required",
      minLength: "Please enter at least #{rules[:min_length]} characters",
      maxLength: "Please enter no more than #{rules[:max_length]} characters",
      min: "Please enter a value greater than or equal to #{rules[:min]}",
      max: "Please enter a value less than or equal to #{rules[:max]}",
      pattern: "Please enter a valid value",
      email: "Please enter a valid email address",
      phone: "Please enter a valid phone number",
      date: "Please enter a valid date",
      options: "Please select a valid option"
    }
    
    client_rules
  end
end