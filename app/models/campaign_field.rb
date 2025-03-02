class CampaignField < ApplicationRecord
  acts_as_tenant :account
  acts_as_list scope: :campaign
  
  belongs_to :campaign
  belongs_to :vertical_field, optional: true
  has_many :list_values, as: :list_owner, dependent: :destroy
  has_rich_text :notes
  
  # Define enums - match VerticalField
  enum :data_type, { text: 0, number: 1, boolean: 2, date: 3, email: 5, phone: 6 }
  enum :value_acceptance, { any: 0, list: 1, range: 2 }
  
  # Legacy field_type constants for backwards compatibility
  FIELD_TYPES = ['text', 'number', 'date', 'datetime', 'email', 'phone', 'select', 'multi_select', 'checkbox', 'radio', 'address'].freeze
  
  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { scope: [:account_id, :campaign_id], message: "already exists in this campaign" }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :validate_list_values_if_list
  validate :validate_range_if_range
  
  # For legacy field_type validation
  validates :field_type, presence: true, inclusion: { in: FIELD_TYPES }, if: -> { data_type.nil? }
  
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
  
  # Field type compatibility methods
  def field_type
    return self[:field_type] if self[:field_type].present?
    
    # Map data_type to field_type
    case data_type
    when 'text', 'email', 'phone'
      data_type.to_s
    when 'number'
      'number'
    when 'date'
      'date'
    when 'boolean'
      value_acceptance == 'list' ? 'radio' : 'checkbox'
    else
      'text'
    end
  end
  
  def field_type=(value)
    self[:field_type] = value
    
    # Map field_type to data_type
    self.data_type = case value
    when 'text', 'email', 'phone'
      value
    when 'number'
      'number'
    when 'date', 'datetime'
      'date'
    when 'checkbox', 'radio', 'select', 'multi_select'
      self.value_acceptance = 'list' unless value == 'checkbox'
      'boolean'
    else
      'text'
    end
  end
  
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
  
  def select?
    field_type == 'select' || (value_acceptance == 'list' && !multi_select?)
  end
  
  def multi_select?
    field_type == 'multi_select'
  end
  
  def checkbox?
    field_type == 'checkbox' || (data_type == 'boolean' && value_acceptance != 'list')
  end
  
  def radio?
    field_type == 'radio' || (data_type == 'boolean' && value_acceptance == 'list')
  end
  
  def address?
    field_type == 'address'
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
end
