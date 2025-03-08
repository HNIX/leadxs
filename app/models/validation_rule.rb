class ValidationRule < ApplicationRecord
  # Associations
  belongs_to :validatable, polymorphic: true, optional: true
  
  # Tenant
  acts_as_tenant :account
  
  # Position management
  # Use different scopes based on association type
  acts_as_list scope: :validatable
  
  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { scope: [:validatable_id, :validatable_type] }, if: -> { validatable_id.present? }
  validates :rule_type, presence: true
  validates :condition, presence: true
  validates :error_message, presence: true
  validates :severity, inclusion: { in: ['info', 'warning', 'error'] }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc) }
  scope :errors_only, -> { where(severity: 'error') }
  scope :warnings_only, -> { where(severity: 'warning') }
  scope :info_only, -> { where(severity: 'info') }
  
  # Rule Types
  RULE_TYPES = {
    condition: 'condition',
    pattern: 'pattern',
    lookup: 'lookup',
    dependency: 'dependency',
    comparison: 'comparison',
    custom: 'custom'
  }
  
  # Severities
  SEVERITIES = {
    info: 'info',         # Just informational, doesn't block lead submission
    warning: 'warning',   # Warns user but allows submission
    error: 'error'        # Prevents lead submission
  }
  
  # Evaluate the validation rule against provided data
  def evaluate(data)
    begin
      result = case rule_type
      when RULE_TYPES[:condition]
        evaluate_condition(data)
      when RULE_TYPES[:pattern]
        evaluate_pattern(data)
      when RULE_TYPES[:lookup]
        evaluate_lookup(data)
      when RULE_TYPES[:dependency]
        evaluate_dependency(data)
      when RULE_TYPES[:comparison]
        evaluate_comparison(data)
      when RULE_TYPES[:custom]
        evaluate_custom(data)
      else
        # Unknown rule type
        false
      end
      
      # Return result hash with validation info
      {
        valid: result,
        rule_id: id,
        rule_name: name,
        error_message: result ? nil : error_message,
        severity: severity
      }
    rescue => e
      # Log the error and return false (validation failed)
      Rails.logger.error("Error evaluating validation rule #{id} (#{name}): #{e.message}")
      
      {
        valid: false,
        rule_id: id,
        rule_name: name,
        error_message: "Internal validation error: #{e.message}",
        severity: 'error'
      }
    end
  end
  
  # Test the validation rule with test data
  def test
    evaluate(test_data)
  end
  
  private
  
  # Evaluate a condition-based rule (uses Ruby DSL with field references)
  def evaluate_condition(data)
    # Create a validation context with data
    context = ValidationContext.new(data)
    
    # Evaluate the condition in the context
    context.evaluate(condition)
  end
  
  # Evaluate pattern-based rule (regex matching)
  def evaluate_pattern(data)
    return false unless parameters['field_name'].present? && parameters['pattern'].present?
    
    field_name = parameters['field_name']
    pattern = parameters['pattern']
    
    # Skip validation if field is not present
    return true unless data.key?(field_name) && data[field_name].present?
    
    # Match the pattern against the field value
    !!data[field_name].to_s.match(Regexp.new(pattern))
  end
  
  # Evaluate lookup-based rule (check value in list)
  def evaluate_lookup(data)
    return false unless parameters['field_name'].present? && parameters['lookup_values'].present?
    
    field_name = parameters['field_name']
    lookup_values = parameters['lookup_values']
    
    # Skip validation if field is not present
    return true unless data.key?(field_name) && data[field_name].present?
    
    # Check if the field value is in the lookup list
    lookup_values.include?(data[field_name].to_s)
  end
  
  # Evaluate dependency-based rule (field A requires field B)
  def evaluate_dependency(data)
    return false unless parameters['primary_field'].present? && parameters['dependent_field'].present?
    
    primary_field = parameters['primary_field']
    dependent_field = parameters['dependent_field']
    
    # Skip validation if primary field is not present
    return true unless data.key?(primary_field) && data[primary_field].present?
    
    # If primary field has a value, dependent field must also have a value
    data.key?(dependent_field) && data[dependent_field].present?
  end
  
  # Evaluate comparison-based rule (field A [op] field B or constant)
  def evaluate_comparison(data)
    return false unless parameters['field_name'].present? && 
                         parameters['operator'].present? && 
                         (parameters['comparison_field'].present? || parameters['comparison_value'].present?)
    
    field_name = parameters['field_name']
    operator = parameters['operator']
    
    # Skip validation if field is not present
    return true unless data.key?(field_name) && data[field_name].present?
    
    # Get comparison value (either from another field or constant)
    comparison_value = if parameters['comparison_field'].present?
      data[parameters['comparison_field']]
    else
      parameters['comparison_value']
    end
    
    # Compare the values based on the operator
    compare_values(data[field_name], comparison_value, operator)
  end
  
  # Evaluate custom rule (custom Ruby code)
  def evaluate_custom(data)
    # This is potentially dangerous, so we need to be very careful
    # A safer approach might be to use a DSL or predefined functions
    
    # For now, we'll just use the condition field directly
    evaluate_condition(data)
  end
  
  # Helper method to compare values with different operators
  def compare_values(value1, value2, operator)
    case operator
    when '=='
      value1.to_s == value2.to_s
    when '!='
      value1.to_s != value2.to_s
    when '>'
      Float(value1) > Float(value2)
    when '>='
      Float(value1) >= Float(value2)
    when '<'
      Float(value1) < Float(value2)
    when '<='
      Float(value1) <= Float(value2)
    when 'includes'
      value1.to_s.include?(value2.to_s)
    when 'starts_with'
      value1.to_s.start_with?(value2.to_s)
    when 'ends_with'
      value1.to_s.end_with?(value2.to_s)
    else
      false
    end
  rescue
    false
  end
  
  # Find all validation rules that apply to a specific field
  # This can be used to find rules from both vertical fields and campaign rules
  def self.for_field(field_name, campaign)
    # Get rules directly associated with the campaign
    campaign_rules = campaign.validation_rules.active.ordered
    
    # Filter rules that apply to this field (either explicitly or implicitly)
    campaign_rules.select do |rule|
      applies_to_field?(rule, field_name)
    end
  end
  
  # Check if a rule applies to a specific field
  def self.applies_to_field?(rule, field_name)
    case rule.rule_type
    when RULE_TYPES[:condition]
      # Check if the field name appears in the condition
      rule.condition.include?("field('#{field_name}')") || 
        rule.condition.include?("field(\"#{field_name}\")")
    when RULE_TYPES[:pattern], RULE_TYPES[:lookup]
      # Check the field_name parameter
      rule.parameters['field_name'] == field_name
    when RULE_TYPES[:dependency]
      # Check both primary and dependent fields
      rule.parameters['primary_field'] == field_name || 
        rule.parameters['dependent_field'] == field_name
    when RULE_TYPES[:comparison]
      # Check both field_name and comparison_field
      rule.parameters['field_name'] == field_name || 
        rule.parameters['comparison_field'] == field_name
    else
      false
    end
  end
  
  # Check if this rule is a campaign-level rule
  def campaign_rule?
    campaign_id.present?
  end
  
  # Check if this rule is a vertical-level rule 
  def vertical_rule?
    vertical_id.present?
  end
  
  # Check if this is a legacy field-level rule
  def field_rule?
    validatable_id.present?
  end
  
  private

  # ValidationContext class for evaluating conditions safely
  class ValidationContext
    def initialize(data)
      @data = data
    end
    
    def evaluate(condition)
      # Replace field('field_name') references with actual values
      expression = condition.gsub(/field\(['"]([^'"]+)['"]\)/) do
        field_name = $1
        if @data.key?(field_name)
          value = @data[field_name]
          # Quote string values, leave numbers as is
          value.is_a?(String) ? "\"#{value.gsub('"', '\\"')}\"" : value.to_s
        else
          "nil"
        end
      end
      
      # Create a clean binding
      binding_context = create_binding
      
      # Evaluate the expression
      binding_context.eval(expression) == true
    end
    
    private
    
    def create_binding
      # Create a clean binding with only safe operations
      clean_binding = binding
      
      # Add helper modules if needed
      string_module = Module.new do
        def self.contains?(str, substr); str.to_s.include?(substr.to_s); end
        def self.starts_with?(str, prefix); str.to_s.start_with?(prefix.to_s); end
        def self.ends_with?(str, suffix); str.to_s.end_with?(suffix.to_s); end
        def self.matches?(str, pattern); !!str.to_s.match(Regexp.new(pattern.to_s)); end
        def self.empty?(str); str.nil? || str.to_s.empty?; end
        def self.length(str); str.to_s.length; end
      end
      
      number_module = Module.new do
        def self.between?(num, min, max); (min..max).include?(num.to_f); end
        def self.positive?(num); num.to_f > 0; end
        def self.negative?(num); num.to_f < 0; end
        def self.zero?(num); num.to_f == 0; end
      end
      
      date_module = Module.new do
        def self.before?(date1, date2); Date.parse(date1.to_s) < Date.parse(date2.to_s); end
        def self.after?(date1, date2); Date.parse(date1.to_s) > Date.parse(date2.to_s); end
        def self.between?(date, start_date, end_date)
          d = Date.parse(date.to_s)
          d >= Date.parse(start_date.to_s) && d <= Date.parse(end_date.to_s)
        end
        def self.today; Date.today.to_s; end
        def self.years_ago(years); (Date.today - (years.to_i * 365)).to_s; end
      end
      
      # Make modules accessible
      clean_binding.local_variable_set(:String, string_module)
      clean_binding.local_variable_set(:Number, number_module)
      clean_binding.local_variable_set(:Date, date_module)
      
      clean_binding
    end
  end
end