class VerticalField < ApplicationRecord
    acts_as_tenant :account
    acts_as_list scope: :vertical
    
    belongs_to :vertical
    has_many :campaign_fields, dependent: :destroy
    has_many :list_values, as: :list_owner, dependent: :destroy
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