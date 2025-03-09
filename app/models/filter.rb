class Filter < ApplicationRecord
  # Using STI (Single Table Inheritance) with the filters table
  # not abstract_class anymore since we're using STI
  self.table_name = 'filters'
  
  # Common attributes for all filter types
  belongs_to :campaign
  belongs_to :campaign_field
  
  # Define status options
  STATUSES = ['active', 'paused', 'archived'].freeze
  
  # Define operators
  OPERATORS = {
    equal: 'equal',
    not_equal: 'not_equal',
    contains: 'contains',
    starts_with: 'starts_with',
    ends_with: 'ends_with',
    greater_than: 'greater_than',
    less_than: 'less_than',
    greater_than_or_equal: 'greater_than_or_equal',
    less_than_or_equal: 'less_than_or_equal',
    in_list: 'in_list',
    not_in_list: 'not_in_list',
    between: 'between'
  }.freeze
  
  # Validations
  validates :campaign, presence: true
  validates :campaign_field, presence: true
  validates :operator, presence: true, inclusion: { in: OPERATORS.values }
  validates :value, presence: true, unless: :between_operator?
  validates :min_value, :max_value, presence: true, if: :between_operator?
  validates :status, presence: true, inclusion: { in: STATUSES }
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :paused, -> { where(status: 'paused') }
  scope :archived, -> { where(status: 'archived') }
  
  # Common methods for all filter types
  
  # Checks if the filter passes for the given data
  def passes?(data)
    field_name = campaign_field.name
    field_value = data[field_name]
    
    # If the field value is nil or empty, the filter doesn't pass
    return false if field_value.nil? || (field_value.is_a?(String) && field_value.empty?)
    
    # Apply operator logic
    case operator
    when OPERATORS[:equal]
      field_value.to_s == value.to_s
    when OPERATORS[:not_equal]
      field_value.to_s != value.to_s
    when OPERATORS[:contains]
      field_value.to_s.include?(value.to_s)
    when OPERATORS[:starts_with]
      field_value.to_s.start_with?(value.to_s)
    when OPERATORS[:ends_with]
      field_value.to_s.end_with?(value.to_s)
    when OPERATORS[:greater_than]
      numeric_comparison(field_value, :>, value)
    when OPERATORS[:less_than]
      numeric_comparison(field_value, :<, value)
    when OPERATORS[:greater_than_or_equal]
      numeric_comparison(field_value, :>=, value)
    when OPERATORS[:less_than_or_equal]
      numeric_comparison(field_value, :<=, value)
    when OPERATORS[:in_list]
      value_list = value.to_s.split(',').map(&:strip)
      value_list.include?(field_value.to_s)
    when OPERATORS[:not_in_list]
      value_list = value.to_s.split(',').map(&:strip)
      !value_list.include?(field_value.to_s)
    when OPERATORS[:between]
      numeric_comparison(field_value, :>=, min_value) && numeric_comparison(field_value, :<=, max_value)
    else
      false
    end
  end
  
  # Applies the filter to a collection of entities
  # This method should be implemented by each child class
  def applies_to?(entity)
    raise NotImplementedError, "Child class must implement this method"
  end
  
  private
  
  def between_operator?
    operator == OPERATORS[:between]
  end
  
  def numeric_comparison(field_value, operator_symbol, compare_value)
    # Convert values to numeric for comparison
    begin
      field_numeric = field_value.to_f
      compare_numeric = compare_value.to_f
      field_numeric.send(operator_symbol, compare_numeric)
    rescue
      false
    end
  end
end