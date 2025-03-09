class CampaignFieldsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_campaign
  before_action :set_campaign_field, only: [:show, :edit, :update, :destroy]

  def index
    @campaign_fields = @campaign.campaign_fields.ordered
    
    respond_to do |format|
      format.html
      format.json do
        render json: @campaign_fields.map { |field| 
          { 
            id: field.id, 
            name: field.name, 
            label: field.label, 
            data_type: field.data_type,
            field_type: field.field_type
          } 
        }
      end
    end
  end
  
  def show
    # The view will access @campaign_field
  end

  def new
    @campaign_field = CampaignField.new
    @campaign_field.list_values.build
    @modal_title = "Add a new field"
  end

  def create
    @campaign_field = @campaign.campaign_fields.new(campaign_field_params)
    
    # Debug output for tests
    Rails.logger.debug("Creating campaign field with params: #{campaign_field_params.inspect}")
    Rails.logger.debug("Campaign Field: #{@campaign_field.inspect}")
    
    respond_to do |format|
      if @campaign_field.save
        Rails.logger.debug("Campaign field saved successfully: #{@campaign_field.id}")
        format.html { redirect_to campaign_path(@campaign), notice: "Field was successfully added." }
        format.json { render :show, status: :created, location: @campaign_field }
      else
        Rails.logger.debug("Failed to save campaign field. Errors: #{@campaign_field.errors.full_messages}")
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @campaign_field.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @campaign_field.list_values.build if @campaign_field.list_values.empty?
    @modal_title = "Edit field"
  end

  def update
    respond_to do |format|
      if @campaign_field.update(campaign_field_params)
        format.html { redirect_to campaign_path(@campaign), notice: "Field was successfully updated." }
        format.json { render :show, status: :ok, location: @campaign_field }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @campaign_field.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @campaign_field.destroy
      redirect_to campaign_path(@campaign), notice: "Field was successfully deleted."
    else
      redirect_to campaign_path(@campaign), alert: "Error deleting field."
    end
  end

  private

  def set_campaign
    @campaign = Campaign.find(params[:campaign_id])
  end

  def set_campaign_field
    @campaign_field = @campaign.campaign_fields.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to campaign_path(@campaign), notice: "Field not found."
  end

  def campaign_field_params
    params.require(:campaign_field).permit(
      :name,
      :label,
      :field_type,  # Adding field_type explicitly to permit list
      :data_type,
      :required,
      :default_value,
      :description,
      :validation_regex,
      :min_length,
      :max_length,
      :min_value,
      :max_value,
      :is_pii,
      :ping_required,
      :post_required,
      :post_only,
      :hide,
      :example_value,
      :value_acceptance,
      options: [],
      list_values_attributes: [:id, :list_value, :value_type, :position, :_destroy]
    )
  end
end
