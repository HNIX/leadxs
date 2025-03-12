class StandardFieldsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_standard_field, only: [:show, :edit, :update, :destroy]
  
  def index
    @standard_fields = current_account.standard_fields.order(position: :asc)
  end

  def show
  end

  def new
    @standard_field = current_account.standard_fields.new
  end

  def create
    @standard_field = current_account.standard_fields.new(standard_field_params)
    
    # Handle the case where value_acceptance is not 'list' but list_values were submitted
    if @standard_field.value_acceptance != 'list'
      params[:standard_field][:list_values_attributes]&.each do |k, v|
        v[:_destroy] = '1' unless v[:_destroy] == '1'
      end
    end
    
    if @standard_field.save
      redirect_to standard_fields_path, notice: "Standard field was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # Handle the case where value_acceptance is not 'list' but list_values were submitted
    if standard_field_params[:value_acceptance] != 'list'
      params[:standard_field][:list_values_attributes]&.each do |k, v|
        v[:_destroy] = '1' unless v[:_destroy] == '1'
      end
    end
    
    if @standard_field.update(standard_field_params)
      redirect_to standard_fields_path, notice: "Standard field was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @standard_field.destroy
    redirect_to standard_fields_path, notice: "Standard field was successfully deleted."
  end
  
  private
  
  def set_standard_field
    @standard_field = current_account.standard_fields.find(params[:id])
  end
  
  def standard_field_params
    params.require(:standard_field).permit(
      :name, :label, :data_type, :value_acceptance, :required, 
      :is_pii, :ping_required, :post_required, :post_only, :hide,
      :default_value, :example_value, :validation_regex, :min_length, 
      :max_length, :min_value, :max_value, :description,
      list_values_attributes: [:id, :list_value, :value_type, :position, :_destroy]
    )
  end
end
