class SourcesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_source, only: [:show, :edit, :update, :destroy]
  before_action :set_campaign, only: [:index, :new, :create]

  # GET /campaigns/:campaign_id/sources
  def index
    @sources = @campaign.sources.includes(:company).order(created_at: :desc)
  end

  # GET /sources/:id
  def show
  end

  # GET /campaigns/:campaign_id/sources/new
  def new
    @source = @campaign.sources.new
  end

  # GET /sources/:id/edit
  def edit
  end

  # POST /campaigns/:campaign_id/sources
  def create
    @source = @campaign.sources.new(source_params)

    if @source.save
      redirect_to source_path(@source), notice: "Source was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /sources/:id
  def update
    if @source.update(source_params)
      redirect_to source_path(@source), notice: "Source was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /sources/:id
  def destroy
    campaign = @source.campaign
    @source.destroy
    redirect_to campaign_sources_path(campaign), notice: "Source was successfully deleted."
  end

  # POST /sources/:id/regenerate_token
  def regenerate_token
    @source = Source.find(params[:id])
    @source.regenerate_token!
    redirect_to source_path(@source), notice: "API token was successfully regenerated."
  end

  private

  def set_source
    @source = Source.find(params[:id])
  end

  def set_campaign
    @campaign = current_account.campaigns.find(params[:campaign_id])
  end

  def source_params
    params.require(:source).permit(
      :name, 
      :status, 
      :integration_type, 
      :payout_method, 
      :payout_structure, 
      :minimum_acceptable_bid, 
      :margin, 
      :payout, 
      :daily_budget, 
      :monthly_budget, 
      :notes, 
      :company_id
    )
  end
end