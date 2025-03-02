class CampaignsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_campaign, only: [:show, :edit, :update, :destroy]
  before_action :set_verticals, only: [:new, :create, :edit, :update]

  def index
    @campaigns = Campaign.includes(:vertical)
  end

  def new
    @campaign = Campaign.new
  end

  def create
    @campaign = Campaign.new(campaign_params)

    respond_to do |format|
      if @campaign.save
        format.html { redirect_to campaign_path(@campaign), notice: "Campaign was successfully created." }
        format.json { render :show, status: :created, location: @campaign }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @campaign.errors, status: :unprocessable_entity }
      end
    end
  end

  def show
    @campaign_fields = @campaign.campaign_fields.ordered
    @calculated_fields = @campaign.calculated_fields.ordered
  end

  def edit
  end

  def update
    respond_to do |format|
      if @campaign.update(campaign_params)
        format.html { redirect_to campaign_path(@campaign), notice: "Campaign was successfully updated." }
        format.json { render :show, status: :ok, location: @campaign }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @campaign.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @campaign.destroy
    respond_to do |format|
      format.html { redirect_to campaigns_path, notice: "Campaign was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def set_campaign
    @campaign = Campaign.find(params[:id])
  end

  def set_verticals
    @verticals = Vertical.active.order(:name)
  end

  def campaign_params
    params.require(:campaign).permit(
      :name, 
      :status, 
      :campaign_type, 
      :description, 
      :distribution_method, 
      :distribution_schedule_enabled, 
      :distribution_schedule_start_time, 
      :distribution_schedule_end_time,
      :vertical_id,
      distribution_schedule_days: []
    )
  end
end
