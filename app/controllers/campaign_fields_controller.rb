class CampaignFieldsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_campaign
  before_action :set_campaign_field, only: [:edit, :update, :destroy]

  def index
    @campaign_fields = @campaign.campaign_fields.ordered
  end

  def new
    @field = CampaignField.new
    @field.list_values.build
    @modal_title = "Add a new field"
  end

  def create
    @field = @campaign.campaign_fields.new(campaign_field_params)
    
    respond_to do |format|
      if @field.save
        format.html { redirect_to campaign_path(@campaign), notice: "Field was successfully added." }
        format.json { render :show, status: :created, location: @field }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @field.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @field.list_values.build if @field.list_values.empty?
    @modal_title = "Edit field"
  end

  def update
    respond_to do |format|
      if @field.update(campaign_field_params)
        format.html { redirect_to campaign_path(@campaign), notice: "Field was successfully updated." }
        format.json { render :show, status: :ok, location: @field }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @field.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @field.destroy
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
    @field = @campaign.campaign_fields.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to campaign_path(@campaign), notice: "Field not found."
  end

  def campaign_field_params
    params.require(:campaign_field).permit(
      :name,
      :label,
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
