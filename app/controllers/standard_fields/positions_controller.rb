module StandardFields
  class PositionsController < ApplicationController
    before_action :authenticate_user!
    
    def update
      params[:position].each_with_index do |id, index|
        current_account.standard_fields.find(id).update(position: index + 1)
      end
      
      head :ok
    end
  end
end