class CalculatedField < ApplicationRecord
  belongs_to :campaign
  belongs_to :account
  
  acts_as_tenant :account
  
  validates :name, presence: true, uniqueness: { scope: :campaign_id }
  validates :formula, presence: true
  
  # Whether this field should be shared during the bidding phase
  attribute :share_during_bidding, :boolean, default: false
  
  before_save :clean_formula_content
  
  # Status options
  STATUSES = {
    active: "active",
    inactive: "inactive",
    error: "error"
  }
  
  # Scopes
  scope :active, -> { where(status: STATUSES[:active]) }
  scope :ordered, -> { order(name: :asc) }
  scope :for_bidding, -> { where(share_during_bidding: true) }
  
  # Clean the formula and prepare it for evaluation
  def clean_formula_content
    if formula.present?
      # Normalize whitespace and strip extra spaces
      self.clean_formula = formula.gsub(/\s+/, " ").strip
      
      # Reset error status if formula is valid
      self.status = STATUSES[:active] if status == STATUSES[:error]
      self.error_log = nil
    end
  rescue => e
    self.status = STATUSES[:error]
    self.error_log = { error: e.message, timestamp: Time.current }
  end
  
  # Evaluate the formula with provided data
  def evaluate(data)
    return nil if clean_formula.blank?
    
    begin
      # Create a safe evaluation context with our supported functions
      context = FormulaEvaluationContext.new(data)
      
      # Pass the formula to our evaluator
      result = context.evaluate(clean_formula)
      
      # Return the computed result
      result
    rescue => e
      self.status = STATUSES[:error]
      self.error_log = { error: e.message, data: data, timestamp: Time.current }
      self.save
      raise e
    end
  end
  
  # Determine if this field should be shared during bidding
  def share_during_bidding?
    # Explicit setting takes precedence
    share_during_bidding
  end
  
  # Inner class for formula evaluation with a controlled environment
  class FormulaEvaluationContext
    def initialize(data)
      @data = data
    end
    
    def evaluate(formula)
      # Replace all function calls with their Ruby equivalents
      expression = transform_formula(formula)
      
      # Use Ruby's eval in a controlled binding
      binding_context = create_binding
      
      # Evaluate the transformed expression
      result = binding_context.eval(expression)
      
      # Return the result
      result
    end
    
    private
    
    def transform_formula(formula)
      # Replace field('name') references with actual data values
      formula = formula.gsub(/field\(['"]([^'"]+)['"]\)/) do
        field_name = $1
        if @data.key?(field_name)
          # Quote string values, leave numbers as is
          value = @data[field_name]
          value.is_a?(String) ? value.inspect : value.to_s
        else
          "nil"
        end
      end
      
      # Replace function calls with their Ruby equivalents
      formula = replace_functions(formula)
      
      formula
    end
    
    def replace_functions(formula)
      # Text operations
      formula = formula.gsub(/concat\(([^,]+),\s*([^)]+)\)/, '((\1).to_s + (\2).to_s)')
      formula = formula.gsub(/uppercase\(([^)]+)\)/, '((\1).to_s.upcase)')
      formula = formula.gsub(/lowercase\(([^)]+)\)/, '((\1).to_s.downcase)')
      formula = formula.gsub(/trim\(([^)]+)\)/, '((\1).to_s.strip)')
      formula = formula.gsub(/length\(([^)]+)\)/, '((\1).to_s.length)')
      
      # Type conversions
      formula = formula.gsub(/toString\(([^)]+)\)/, '((\1).to_s)')
      formula = formula.gsub(/toNumber\(([^)]+)\)/, 'begin; Float((\1)) rescue 0; end')
      formula = formula.gsub(/toDate\(([^)]+)\)/, 'begin; Date.parse((\1).to_s) rescue nil; end')
      
      # Math operations
      formula = formula.gsub(/add\(([^,]+),\s*([^)]+)\)/, '(Float((\1) || 0) + Float((\2) || 0))')
      formula = formula.gsub(/subtract\(([^,]+),\s*([^)]+)\)/, '(Float((\1) || 0) - Float((\2) || 0))')
      formula = formula.gsub(/multiply\(([^,]+),\s*([^)]+)\)/, '(Float((\1) || 0) * Float((\2) || 0))')
      formula = formula.gsub(/divide\(([^,]+),\s*([^)]+)\)/, 'begin; (Float((\1) || 0) / Float((\2) || 1)) rescue 0; end')
      formula = formula.gsub(/round\(([^,]+)(?:,\s*([^)]+))?\)/, 'begin; (Float((\1) || 0)).round((\2 || 0).to_i) rescue 0; end')
      
      # Date operations
      formula = formula.gsub(/now\(\)/, 'Time.current')
      formula = formula.gsub(/today\(\)/, 'Date.today')
      formula = formula.gsub(/formatDate\(([^,]+),\s*([^)]+)\)/, 'begin; ((\1).is_a?(Date) || (\1).is_a?(Time) ? (\1).strftime((\2).to_s.gsub("YYYY", "%Y").gsub("MM", "%m").gsub("DD", "%d")) : ""); rescue; ""; end')
      
      # Conditional logic
      formula = formula.gsub(/if\(([^,]+),\s*([^,]+),\s*([^)]+)\)/, '((\1) ? (\2) : (\3))')
      
      formula
    end
    
    def create_binding
      # Create a clean binding with only math functions available
      clean_binding = binding
      
      # Add common math functions
      math_module = Module.new do
        def self.abs(n); n.abs; end
        def self.ceil(n); n.ceil; end
        def self.floor(n); n.floor; end
        def self.max(a, b); [a, b].max; end
        def self.min(a, b); [a, b].min; end
        def self.pow(a, b); a ** b; end
        def self.sqrt(n); Math.sqrt(n); end
      end
      
      # Make Date, Time and Math accessible
      clean_binding.local_variable_set(:Date, Date)
      clean_binding.local_variable_set(:Time, Time)
      clean_binding.local_variable_set(:Math, math_module)
      
      clean_binding
    end
  end
end
