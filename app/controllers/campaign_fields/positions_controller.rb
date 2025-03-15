class CampaignFields::PositionsController < ApplicationController
  before_action :authenticate_user\!
  before_action :set_campaign
  before_action :set_campaign_field
  
  def update
    # Get the new position from params
    new_position = params[:position].to_i
    
    if @campaign_field.insert_at(new_position)
      head :ok
    else
      head :unprocessable_entity
    end
  end
  
  private
  
  def set_campaign
    @campaign = Campaign.find(params[:campaign_id])
  end
  
  def set_campaign_field
    @campaign_field = @campaign.campaign_fields.find(params[:campaign_field_id])
  end
end
