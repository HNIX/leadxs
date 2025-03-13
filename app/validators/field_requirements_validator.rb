class FieldRequirementsValidator
  attr_reader :campaign, :data

  def initialize(campaign, data)
    @campaign = campaign
    @data = data
  end

  def validate
    validation_failures = {}
    
    # Check for required fields
    campaign.campaign_fields.where(required: true).each do |field|
      # If the field name is not in the data hash, or it's nil or empty string
      field_value = data[field.name]
      has_value = field_value.present?
      
      # Skip if the field has a valid value
      next if has_value
      
      # Field is required but missing or empty
      field_label = field.label.presence || field.name.to_s.humanize
      validation_failures[field.name] = {
        rule_name: "Required Field: #{field_label}",
        message: "#{field_label} is required",
        severity: "error",
        rule_id: "required_#{field.id}",
        field: field.name
      }
    end
    
    validation_failures
  end
end