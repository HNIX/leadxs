class CampaignFieldsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_campaign
  before_action :set_campaign_field, only: [:edit, :update, :destroy]

  def index
    @campaign_fields = @campaign.campaign_fields.ordered
  end

  def new
    @campaign_field = @campaign.campaign_fields.new
  end

  def create
    @campaign_field = @campaign.campaign_fields.new(campaign_field_params)
    @campaign_field.position = @campaign.campaign_fields.count

    respond_to do |format|
      if @campaign_field.save
        format.html { redirect_to campaign_path(@campaign), notice: "Field was successfully added." }
        format.json { render :show, status: :created, location: @campaign_field }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @campaign_field.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
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
    @campaign_field.destroy
    respond_to do |format|
      format.html { redirect_to campaign_path(@campaign), notice: "Field was successfully removed." }
      format.json { head :no_content }
    end
  end

  private

  def set_campaign
    @campaign = Campaign.find(params[:campaign_id])
  end

  def set_campaign_field
    @campaign_field = @campaign.campaign_fields.find(params[:id])
  end

  def campaign_field_params
    params.require(:campaign_field).permit(
      :name,
      :label,
      :field_type,
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
