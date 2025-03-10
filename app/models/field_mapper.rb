# app/models/field_mapper.rb
class FieldMapper
  attr_reader :lead, :campaign_distribution, :distribution, :campaign
  
  def initialize(lead, campaign_distribution)
    @lead = lead
    @campaign_distribution = campaign_distribution
    @distribution = campaign_distribution.distribution
    @campaign = lead.campaign
  end
  
  # Build a complete payload from mapped fields
  def build_payload
    payload = {}
    
    # Get all field mappings
    @campaign_distribution.mapped_fields.each do |mapped_field|
      field_name = mapped_field.distribution_field_name
      field_value = get_field_value(mapped_field)
      
      # Skip nil values unless required
      next if field_value.nil? && !mapped_field.required?
      
      # Add to payload
      payload[field_name] = field_value
    end
    
    # Add any additional required metadata
    enrich_payload_with_metadata(payload)
    
    payload
  end
  
  # Get complete processed data for a lead
  def all_lead_data
    data = {}
    
    # Get campaign field values
    @lead.lead_data.each do |lead_data|
      data[lead_data.campaign_field.name] = lead_data.value if lead_data.campaign_field
    end
    
    # Add calculated field values
    @campaign.calculated_fields.each do |calc_field|
      if @lead.field_value(calc_field)
        data[calc_field.name] = @lead.field_value(calc_field)
      end
    end
    
    # Apply any data transformations needed
    transform_data(data)
    
    data
  end
  
  private
  
  # Get the appropriate value for a mapped field (dynamic or static)
  def get_field_value(mapped_field)
    if mapped_field.static?
      mapped_field.static_value
    else
      get_dynamic_field_value(mapped_field)
    end
  end
  
  # Get the dynamic field value with appropriate transformations
  def get_dynamic_field_value(mapped_field)
    # If no campaign field is mapped, return nil
    return nil unless mapped_field.campaign_field_id
    
    # Find the campaign field
    campaign_field = find_field(mapped_field.campaign_field_id)
    return nil unless campaign_field
    
    # Get raw value
    raw_value = case campaign_field
                when CampaignField
                  @lead.lead_data.find_by(campaign_field_id: campaign_field.id)&.value
                when CalculatedField
                  @lead.field_value(campaign_field)
                else
                  nil
                end
    
    # Transform value if needed for this distribution
    transform_field_value(raw_value, campaign_field, mapped_field)
  end
  
  # Find a field (campaign or calculated) by ID
  def find_field(field_id)
    @campaign.campaign_fields.find_by(id: field_id) || 
    @campaign.calculated_fields.find_by(id: field_id)
  end
  
  # Apply any field-specific transformations required by the distribution
  def transform_field_value(value, field, mapped_field)
    return nil if value.nil?
    
    # Check if field has a specific format required for this distribution
    format_preference = mapped_field.format_preference
    
    case field.field_type
    when 'phone'
      format_phone(value, format_preference)
    when 'email'
      format_email(value, format_preference)
    when 'date'
      format_date(value, format_preference)
    when 'boolean'
      format_boolean(value, format_preference)
    when 'number'
      format_number(value, format_preference)
    else
      value.to_s
    end
  end
  
  # Format phone numbers based on preference
  def format_phone(value, preference)
    case preference
    when 'digits_only'
      value.to_s.gsub(/\D/, '')
    when 'formatted'
      # Format as (XXX) XXX-XXXX
      digits = value.to_s.gsub(/\D/, '')
      if digits.length == 10
        "(#{digits[0..2]}) #{digits[3..5]}-#{digits[6..9]}"
      else
        value
      end
    else
      value
    end
  end
  
  # Format email addresses (usually standardization or lowercase)
  def format_email(value, preference)
    case preference
    when 'lowercase'
      value.to_s.downcase
    else
      value
    end
  end
  
  # Format dates based on preference
  def format_date(value, preference)
    return value if value.nil?
    
    begin
      date = value.is_a?(Date) ? value : Date.parse(value.to_s)
      case preference
      when 'iso'
        date.iso8601
      when 'mmddyyyy'
        date.strftime('%m/%d/%Y')
      when 'yyyymmdd'
        date.strftime('%Y-%m-%d')
      else
        value
      end
    rescue
      value
    end
  end
  
  # Format boolean values based on preference
  def format_boolean(value, preference)
    case preference
    when 'yn'
      value ? 'Y' : 'N'
    when 'truefalse'
      value ? 'true' : 'false'
    when '10'
      value ? '1' : '0'
    else
      value
    end
  end
  
  # Format numbers based on preference
  def format_number(value, preference)
    case preference
    when 'integer'
      value.to_i.to_s
    when 'decimal'
      "%.2f" % value.to_f
    when 'currency'
      "$%.2f" % value.to_f
    else
      value
    end
  end
  
  # Transform all data according to distribution's requirements
  def transform_data(data)
    # Apply any required global transformations
    # e.g., normalizing case, formatting, etc.
    data
  end
  
  # Add any required metadata to the payload
  def enrich_payload_with_metadata(payload)
    # Add standard metadata fields required by the distribution
    case @distribution.metadata_requirements
    when 'include_standard_fields'
      # Add standard tracking fields
      payload['lead_id'] = @lead.unique_id
      payload['campaign_id'] = @campaign.id
      payload['timestamp'] = Time.current.iso8601
      payload['source_id'] = @lead.source&.id
      payload['request_id'] = SecureRandom.uuid
    when 'include_extended_fields'
      # Add extended tracking fields
      payload['lead_id'] = @lead.unique_id
      payload['campaign_id'] = @campaign.id
      payload['campaign_name'] = @campaign.name
      payload['timestamp'] = Time.current.iso8601
      payload['source_id'] = @lead.source&.id
      payload['source_name'] = @lead.source&.name
      payload['distribution_id'] = @distribution.id
      payload['account_id'] = @campaign.account_id
      payload['request_id'] = SecureRandom.uuid
    end
    
    # Also check no_metadata for backward compatibility
    if @distribution.metadata_requirements == 'no_metadata' && @distribution.custom_metadata_fields.present?
      # Even if no standard metadata is required, we might have custom fields
      payload.merge!(@distribution.custom_metadata_fields)
    end
    
    # Add custom metadata fields if configured
    @distribution.custom_metadata_fields&.each do |field, value|
      payload[field] = value
    end
    
    payload
  end
end