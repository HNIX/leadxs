class ValidationRuleProcessor
  attr_reader :rule, :data, :lead

  def initialize(rule, data, lead = nil)
    @rule = rule
    @data = data
    @lead = lead
  end

  # Evaluate the validation rule against the provided data
  def evaluate
    begin
      # Handle special patterns for required fields
      if rule.rule_type == ValidationRule::RULE_TYPES[:condition] && 
         rule.condition.match?(/!String\.empty\?\(field\(['"]([^'"]+)['"]\)\)/)
        # Extract field name from expression
        field_name = $1
        
        # Look up the field in the campaign to get a proper label
        campaign_field = find_campaign_field(field_name)
        field_label = campaign_field&.label || (field_name || "").humanize
        
        # This is a required field validation - check if the field has a value
        field_value = data[field_name]
        result = field_value.present?
        
        # Return result object
        return ValidationResult.new(
          valid: result,
          rule_id: rule.id,
          rule_name: "Required Field: #{field_label}",
          message: result ? nil : "#{field_label} is required",
          severity: rule.severity
        )
      end
      
      # Normal rule evaluation
      result = case rule.rule_type
      when ValidationRule::RULE_TYPES[:condition]
        evaluate_condition
      when ValidationRule::RULE_TYPES[:pattern]
        evaluate_pattern
      when ValidationRule::RULE_TYPES[:lookup]
        evaluate_lookup
      when ValidationRule::RULE_TYPES[:dependency]
        evaluate_dependency
      when ValidationRule::RULE_TYPES[:comparison]
        evaluate_comparison
      when ValidationRule::RULE_TYPES[:custom]
        evaluate_custom
      else
        # Unknown rule type
        false
      end
      
      # Return result object with validation info
      ValidationResult.new(
        valid: result,
        rule_id: rule.id,
        rule_name: rule.name,
        message: result ? nil : rule.error_message,
        severity: rule.severity
      )
    rescue => e
      # Log the error and return failure result
      Rails.logger.error("Error evaluating validation rule #{rule.id} (#{rule.name}): #{e.message}")
      
      ValidationResult.new(
        valid: false,
        rule_id: rule.id,
        rule_name: rule.name,
        message: "#{rule.error_message || 'Validation error'} (#{e.message})",
        severity: 'error'
      )
    end
  end

  private
  
  # Helper to find a campaign field by name
  def find_campaign_field(field_name)
    return nil unless lead&.campaign
    lead.campaign.campaign_fields.find_by(name: field_name)
  end

  # Evaluate a condition-based rule (uses Ruby DSL with field references)
  def evaluate_condition
    # Create a validation context with data
    context = ValidationContext.new(data)
    
    # Evaluate the condition in the context
    context.evaluate(rule.condition)
  end
  
  # Evaluate pattern-based rule (regex matching)
  def evaluate_pattern
    return false unless rule.parameters['field_name'].present? && rule.parameters['pattern'].present?
    
    field_name = rule.parameters['field_name']
    pattern = rule.parameters['pattern']
    
    # Skip validation if field is not present
    return true unless data.key?(field_name) && data[field_name].present?
    
    # Match the pattern against the field value
    !!data[field_name].to_s.match(Regexp.new(pattern))
  end
  
  # Evaluate lookup-based rule (check value in list)
  def evaluate_lookup
    return false unless rule.parameters['field_name'].present? && rule.parameters['lookup_values'].present?
    
    field_name = rule.parameters['field_name']
    lookup_values = rule.parameters['lookup_values']
    
    # Skip validation if field is not present
    return true unless data.key?(field_name) && data[field_name].present?
    
    # Check if the field value is in the lookup list
    lookup_values.include?(data[field_name].to_s)
  end
  
  # Evaluate dependency-based rule (field A requires field B)
  def evaluate_dependency
    return false unless rule.parameters['primary_field'].present? && rule.parameters['dependent_field'].present?
    
    primary_field = rule.parameters['primary_field']
    dependent_field = rule.parameters['dependent_field']
    
    # Skip validation if primary field is not present
    return true unless data.key?(primary_field) && data[primary_field].present?
    
    # If primary field has a value, dependent field must also have a value
    data.key?(dependent_field) && data[dependent_field].present?
  end
  
  # Evaluate comparison-based rule (field A [op] field B or constant)
  def evaluate_comparison
    return false unless rule.parameters['field_name'].present? && 
                        rule.parameters['operator'].present? && 
                        (rule.parameters['comparison_field'].present? || rule.parameters['comparison_value'].present?)
    
    field_name = rule.parameters['field_name']
    operator = rule.parameters['operator']
    
    # Skip validation if field is not present
    return true unless data.key?(field_name) && data[field_name].present?
    
    # Get comparison value (either from another field or constant)
    comparison_value = if rule.parameters['comparison_field'].present?
      data[rule.parameters['comparison_field']]
    else
      rule.parameters['comparison_value']
    end
    
    # Compare the values based on the operator
    compare_values(data[field_name], comparison_value, operator)
  end
  
  # Evaluate custom rule (custom Ruby code)
  def evaluate_custom
    # Use the condition field for custom rules
    evaluate_condition
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
      
      # Evaluate the expression with error handling
      begin
        binding_context.eval(expression) == true
      rescue => e
        Rails.logger.error("Validation rule evaluation error: #{e.message} for expression: #{expression}")
        false
      end
    end
    
    private
    
    def create_binding
      # Create a clean binding with only safe operations
      clean_binding = binding
      
      # Add helper methods directly to the binding
      clean_binding.eval(<<~RUBY)
        # String helper methods
        def string_contains?(str, substr)
          str.to_s.include?(substr.to_s)
        end
        
        def string_starts_with?(str, prefix)
          str.to_s.start_with?(prefix.to_s)
        end
        
        def string_ends_with?(str, suffix)
          str.to_s.end_with?(suffix.to_s)
        end
        
        def string_matches?(str, pattern)
          !!str.to_s.match(Regexp.new(pattern.to_s))
        end
        
        def string_empty?(str)
          str.nil? || str.to_s.strip == ''
        end
        
        def string_length(str)
          str.to_s.length
        end
        
        # For backward compatibility with existing rules
        module String
          def self.empty?(str)
            str.nil? || str.to_s.strip == ''
          end
          
          def self.contains?(str, substr)
            str.to_s.include?(substr.to_s)
          end
          
          def self.starts_with?(str, prefix)
            str.to_s.start_with?(prefix.to_s)
          end
          
          def self.ends_with?(str, suffix)
            str.to_s.end_with?(suffix.to_s)
          end
          
          def self.matches?(str, pattern)
            !!str.to_s.match(Regexp.new(pattern.to_s))
          end
          
          def self.length(str)
            str.to_s.length
          end
        end
        
        # Number helper methods
        def number_between?(num, min, max)
          (min.to_f..max.to_f).include?(num.to_f)
        end
        
        def number_positive?(num)
          num.to_f > 0
        end
        
        def number_negative?(num)
          num.to_f < 0
        end
        
        def number_zero?(num)
          num.to_f == 0
        end
        
        # Date helper methods
        def date_before?(date1, date2)
          begin
            Date.parse(date1.to_s) < Date.parse(date2.to_s)
          rescue
            false
          end
        end
        
        def date_after?(date1, date2)
          begin
            Date.parse(date1.to_s) > Date.parse(date2.to_s)
          rescue
            false
          end
        end
        
        def date_between?(date, start_date, end_date)
          begin
            d = Date.parse(date.to_s)
            d >= Date.parse(start_date.to_s) && d <= Date.parse(end_date.to_s)
          rescue
            false
          end
        end
        
        def date_today
          Date.today.to_s
        end
        
        def required_field?(field_value)
          !(field_value.nil? || field_value.to_s.strip == '')
        end
      RUBY
      
      clean_binding
    end
  end
end

# Value object to represent validation result
class ValidationResult
  attr_reader :valid, :rule_id, :rule_name, :message, :severity
  
  def initialize(valid:, rule_id:, rule_name:, message: nil, severity: 'error')
    @valid = valid
    @rule_id = rule_id
    @rule_name = rule_name
    @message = message
    @severity = severity
  end
  
  def valid?
    @valid
  end
  
  def error?
    !@valid && @severity == 'error'
  end
  
  def warning?
    !@valid && @severity == 'warning'
  end
  
  def info?
    !@valid && @severity == 'info'
  end
end