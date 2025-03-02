json.array! @campaign_fields do |field|
  json.extract! field, :id, :name, :label, :field_type, :data_type, :required, :value_acceptance
  
  # Include data type helper methods for the front-end
  json.is_text field.text?
  json.is_number field.number?
  json.is_date field.date?
  json.is_email field.email?
  json.is_phone field.phone?
  json.is_boolean field.boolean?
  json.is_select field.select?
  json.is_multi_select field.multi_select?
  json.is_checkbox field.checkbox?
  json.is_radio field.radio?
  json.is_address field.address?
  
  # Include list values if applicable
  if field.value_acceptance == 'list'
    json.list_values field.list_values.map(&:list_value)
  end
  
  # Include range values if applicable
  if field.value_acceptance == 'range'
    json.min_value field.min_value
    json.max_value field.max_value
  end
end