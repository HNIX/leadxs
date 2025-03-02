class VerticalFields::PositionsController < ApplicationController
    def update
      @vertical = Vertical.find(params[:vertical_id])
      @field = @vertical.vertical_fields.find(params[:vertical_field_id])
     
      @field.insert_at(params[:position].to_i)
      head :no_content
    end
  end