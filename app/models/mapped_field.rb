class MappedField < ApplicationRecord
  belongs_to :campaign_distribution
  
  enum :value_type, {
    dynamic: 0,   # Uses campaign field value 
    static: 1     # Uses static value specified
  }, default: :dynamic
  
  # Define available format preferences for different field types
  FORMAT_PREFERENCES = {
    phone: ['default', 'digits_only', 'formatted'],
    email: ['default', 'lowercase'],
    date: ['default', 'iso', 'mmddyyyy', 'yyyymmdd'],
    boolean: ['default', 'yn', 'truefalse', '10'],
    number: ['default', 'integer', 'decimal', 'currency']
  }.freeze
  
  validates :distribution_field_name, presence: true, uniqueness: { scope: :campaign_distribution_id }
  validates :static_value, presence: true, if: -> { static? }
  
  # Allow storing format preference in JSON
  store_accessor :preferences, :format_preference, :validation_rules
  
  def campaign_field
    return nil unless campaign_field_id.present?
    # Try campaign fields first, then calculated fields
    field = CampaignField.find_by(id: campaign_field_id)
    field ||= CalculatedField.find_by(id: campaign_field_id) 
    field
  end
  
  # Get the value for this mapped field for a given lead
  def value_for_lead(lead)
    if dynamic?
      # Find the lead data for this campaign field
      lead_data = lead.lead_data.find_by(campaign_field_id: campaign_field_id)
      
      # If it's a campaign field with data
      if lead_data&.value.present?
        lead_data.value
      elsif campaign_field.is_a?(CalculatedField)
        # If it's a calculated field
        lead.field_value(campaign_field)
      else
        # No value found
        nil
      end
    else
      # Return static value
      static_value
    end
  end
  
  # Get the appropriate format preference or default if not set
  def format_preference
    super || 'default'
  end
  
  # Determine available format options based on field type
  def available_format_preferences
    return [] unless campaign_field
    field_type = campaign_field.field_type
    FORMAT_PREFERENCES[field_type.to_sym] || ['default']
  end
end
