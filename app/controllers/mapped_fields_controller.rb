class MappedFieldsController < ApplicationController
  before_action :set_campaign_distribution

  def index
    @campaign = @campaign_distribution.campaign
    @distribution = @campaign_distribution.distribution
    @campaign_fields = @campaign.campaign_fields
    @mapped_fields = @campaign_distribution.mapped_fields
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def update_mappings
    successful = true
    
    # Process the updated mappings
    if mapping_params[:mappings].present?
      mapping_params[:mappings].each do |field_id, field_params|
        mapped_field = @campaign_distribution.mapped_fields.find_by(id: field_id)
        
        # Only update if the field exists (extra security check)
        if mapped_field && !mapped_field.update(
            campaign_field_id: field_params[:campaign_field_id],
            distribution_field_name: field_params[:distribution_field_name],
            static_value: field_params[:static_value],
            value_type: field_params[:value_type],
            required: field_params[:required]
          )
          successful = false
          break
        end
      end
    end
    
    # Process new mappings
    if new_mapping_params[:new_mappings].present? && successful
      new_mapping_params[:new_mappings].each do |idx, field_params|
        # Skip empty entries
        next if field_params[:distribution_field_name].blank?
        
        # Create new field mapping
        new_field = @campaign_distribution.mapped_fields.new(
          campaign_field_id: field_params[:campaign_field_id],
          distribution_field_name: field_params[:distribution_field_name],
          static_value: field_params[:static_value],
          value_type: field_params[:value_type],
          required: field_params[:required].present?
        )
        
        unless new_field.save
          successful = false
          break
        end
      end
    end

    respond_to do |format|
      if successful
        # Redirect back to distribution view in turbo frame or normal view
        campaign = @campaign_distribution.campaign
        format.html { 
          redirect_to campaign_distribution_path(@campaign_distribution), 
          notice: "Field mappings were successfully updated." 
        }
        format.turbo_stream { 
          redirect_to configure_campaign_path(campaign, anchor: 'distribution'),
          notice: "Field mappings were successfully updated."
        }
        format.json { render json: { status: "success" } }
      else
        format.html { 
          redirect_to campaign_distribution_mapped_fields_path(@campaign_distribution), 
          alert: "Error updating field mappings." 
        }
        format.turbo_stream { 
          redirect_to campaign_distribution_mapped_fields_path(@campaign_distribution), 
          alert: "Error updating field mappings." 
        }
        format.json { render json: { status: "error" }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_campaign_distribution
    @campaign_distribution = CampaignDistribution.find(params[:campaign_distribution_id])
  end

  def mapping_params
    params.permit(mappings: [:campaign_field_id, :distribution_field_name, :static_value, :value_type, :required])
  end
  
  def new_mapping_params
    params.permit(new_mappings: [:campaign_field_id, :distribution_field_name, :static_value, :value_type, :required])
  end
end
