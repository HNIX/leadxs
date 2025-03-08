module ValidationRules
  class PositionsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_validatable
    
    def update
      ActiveRecord::Base.transaction do
        position_params[:positions].each do |id, position|
          @validatable.validation_rules.find(id).update(position: position)
        end
      end
      
      head :ok
    end
    
    private
    
    def set_validatable
      if params[:vertical_field_id]
        @validatable = current_account.verticals.find(params[:vertical_id]).vertical_fields.find(params[:vertical_field_id])
      elsif params[:campaign_field_id]
        @validatable = current_account.campaigns.find(params[:campaign_id]).campaign_fields.find(params[:campaign_field_id])
      else
        raise ActionController::RoutingError.new('Not Found')
      end
    end
    
    def position_params
      params.require(:positions).permit(positions: {})
    end
  end
end