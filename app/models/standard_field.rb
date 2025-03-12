class StandardField < ApplicationRecord
  acts_as_tenant :account
  acts_as_list
  
  belongs_to :account
  has_many :list_values, as: :list_owner, dependent: :destroy
  has_rich_text :notes
  
  # Define enums
  enum :data_type, { text: 0, number: 1, boolean: 2, date: 3, email: 5, phone: 6 }
  enum :value_acceptance, { any: 0, list: 1, range: 2 }
  
  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :data_type, presence: true
  validate :validate_list_values_if_list
  validate :validate_range_if_range
  
  accepts_nested_attributes_for :list_values, allow_destroy: true, reject_if: ->(attributes) { 
    # Reject if list_value is blank 
    attributes['list_value'].blank? 
  }

  # Apply standard fields to a vertical (both new and existing)
  # Returns the number of fields added
  def self.apply_to_vertical(vertical)
    account = vertical.account
    fields_added = 0
    
    # Find all standard fields for this account
    account.standard_fields.order(position: :asc).each_with_index do |standard_field, index|
      # Skip if a field with this name already exists
      next if vertical.vertical_fields.exists?(name: standard_field.name)
      
      # Create the vertical field based on the standard field
      vertical_field = vertical.vertical_fields.create!(
        name: standard_field.name,
        label: standard_field.label,
        data_type: standard_field.data_type,
        value_acceptance: standard_field.value_acceptance,
        required: standard_field.required,
        description: standard_field.description,
        is_pii: standard_field.is_pii,
        ping_required: standard_field.ping_required,
        post_required: standard_field.post_required,
        post_only: standard_field.post_only,
        hide: standard_field.hide,
        default_value: standard_field.default_value,
        example_value: standard_field.example_value,
        validation_regex: standard_field.validation_regex,
        min_length: standard_field.min_length,
        max_length: standard_field.max_length,
        min_value: standard_field.min_value,
        max_value: standard_field.max_value,
        position: vertical.vertical_fields.count + index,
        account: account
      )
      
      # Copy list values if any
      standard_field.list_values.each do |list_value|
        vertical_field.list_values.create!(
          list_value: list_value.list_value,
          value_type: list_value.value_type,
          position: list_value.position,
          account: account
        )
      end
      
      fields_added += 1
    end
    
    fields_added
  end
  
  # Sync standard fields with vertical fields
  # This updates existing fields to match standard fields definitions
  # Returns the number of fields updated
  def self.sync_with_vertical(vertical)
    account = vertical.account
    fields_updated = 0
    
    # Find all standard fields for this account
    account.standard_fields.order(position: :asc).each do |standard_field|
      # Find matching vertical field by name
      vertical_field = vertical.vertical_fields.find_by(name: standard_field.name)
      
      # If no matching field, skip (this shouldn't create new fields)
      next unless vertical_field
      
      # Check if an update is needed by comparing attributes
      needs_update = false
      
      # List of attributes to compare and sync
      sync_attributes = %w[
        label data_type value_acceptance required is_pii ping_required
        post_required post_only hide default_value example_value
        validation_regex min_length max_length min_value max_value
      ]
      
      sync_attributes.each do |attr|
        if vertical_field.send(attr) != standard_field.send(attr)
          vertical_field.send("#{attr}=", standard_field.send(attr))
          needs_update = true
        end
      end
      
      # Save the field if updates were made
      if needs_update && vertical_field.save
        fields_updated += 1
        
        # Handle list values if value_acceptance is 'list'
        if standard_field.value_acceptance == 'list'
          # Get existing list values
          existing_values = vertical_field.list_values.pluck(:list_value)
          standard_values = standard_field.list_values.pluck(:list_value)
          
          # Delete any list values that no longer exist in standard field
          # vertical_field.list_values.where.not(list_value: standard_values).destroy_all
          
          # Add any new list values from standard field
          standard_field.list_values.each do |list_value|
            unless existing_values.include?(list_value.list_value)
              vertical_field.list_values.create!(
                list_value: list_value.list_value,
                value_type: list_value.value_type,
                position: list_value.position,
                account: account
              )
            end
          end
        end
      end
    end
    
    fields_updated
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
