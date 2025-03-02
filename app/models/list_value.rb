class ListValue < ApplicationRecord
    # Associations
    acts_as_tenant :account

    belongs_to :list_owner, polymorphic: true
    
    validates :list_value, presence: true
    
    enum :value_type, { string: 0, number: 1 }
    
    # Add validation for number format if value_type is number
    validate :validate_number_format, if: -> { number? }
    
    private
    
    def validate_number_format
      unless valid_number?(list_value)
        errors.add(:list_value, "must be a valid number")
      end
    end
    
    def valid_number?(value)
      true if Float(value) rescue false
    end
  end