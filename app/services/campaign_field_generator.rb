class CampaignFieldGenerator
  def initialize(campaign)
    @campaign = campaign
    @vertical = campaign.vertical
  end
  
  def generate_fields!
    return unless @vertical.present?
    
    ActiveRecord::Base.transaction do
      @vertical.vertical_fields.order(position: :asc).each do |vertical_field|
        # Skip if a field with this name already exists
        next if @campaign.campaign_fields.exists?(name: vertical_field.name)
        
        # Determine field type for backwards compatibility
        field_type = case vertical_field.data_type.to_s
                     when 'text', 'email', 'phone'
                       vertical_field.data_type.to_s
                     when 'number'
                       'number'
                     when 'date'
                       'date'
                     when 'boolean'
                       vertical_field.value_acceptance.to_s == 'list' ? 'radio' : 'checkbox'
                     else
                       'text'
                     end
        
        # Create the campaign field
        campaign_field = @campaign.campaign_fields.new(
          name: vertical_field.name,
          label: vertical_field.label,
          field_type: field_type,
          data_type: vertical_field.data_type,
          position: vertical_field.position,
          required: vertical_field.required,
          is_pii: vertical_field.is_pii,
          ping_required: vertical_field.ping_required,
          post_required: vertical_field.post_required,
          post_only: vertical_field.post_only,
          hide: vertical_field.hide,
          default_value: vertical_field.default_value,
          example_value: vertical_field.example_value,
          value_acceptance: vertical_field.value_acceptance,
          min_value: vertical_field.min_value,
          max_value: vertical_field.max_value,
          description: vertical_field.notes&.to_plain_text.presence || "",
          vertical_field_id: vertical_field.id,
          account_id: @campaign.account_id
        )
        
        # For fields with list values, we need to create the list values first
        # to avoid validation errors (validation requires list values when value_acceptance is 'list')
        if vertical_field.value_acceptance.to_s == 'list'
          # Temporarily bypass validations to avoid list value requirement
          # We'll add list values right after
          campaign_field.save(validate: false)
          
          # Copy list values
          vertical_field.list_values.order(position: :asc).each do |list_value|
            campaign_field.list_values.create!(
              list_value: list_value.list_value,
              value_type: list_value.value_type,
              position: list_value.position,
              account_id: @campaign.account_id
            )
          end
          
          # Validate after adding list values
          unless campaign_field.valid?
            raise ActiveRecord::RecordInvalid.new(campaign_field)
          end
        else
          # For non-list fields, save with validation
          campaign_field.save!
        end
      end
    end
  end
end