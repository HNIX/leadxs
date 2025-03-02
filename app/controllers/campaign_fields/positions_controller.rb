class CampaignFields::PositionsController < ApplicationController
  def update
    @campaign = Campaign.find(params[:campaign_id])
    @field = @campaign.campaign_fields.find(params[:campaign_field_id])
   
    @field.insert_at(params[:position].to_i)
    head :no_content
  end
end