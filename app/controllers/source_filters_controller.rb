class SourceFiltersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_campaign
  before_action :set_source_filter, only: [:show, :edit, :update, :destroy]
  
  def index
    @source_filters = @campaign.source_filters.includes(:campaign_field, :sources).where(type: 'SourceFilter')
    @fields = @campaign.campaign_fields.ordered.map { |field| [field.label || field.name, field.id] }
    @operators = Filter::OPERATORS.map { |key, value| [key.to_s.titleize, value] }
    @sources = @campaign.sources.active
  end
  
  def show
  end
  
  def new
    @source_filter = SourceFilter.new(status: 'active', apply_to_all: true, campaign: @campaign, account: current_account)
    @fields = @campaign.campaign_fields.ordered.map { |field| [field.label || field.name, field.id] }
    @operators = Filter::OPERATORS.map { |key, value| [key.to_s.titleize, value] }
    @sources = @campaign.sources.active
  end
  
  def edit
    @fields = @campaign.campaign_fields.ordered.map { |field| [field.label || field.name, field.id] }
    @operators = Filter::OPERATORS.map { |key, value| [key.to_s.titleize, value] }
    @sources = @campaign.sources.active
  end
  
  def create
    @source_filter = SourceFilter.new(source_filter_params)
    @source_filter.campaign = @campaign
    @source_filter.account = current_account
    @source_filter.type = 'SourceFilter'
    
    respond_to do |format|
      if @source_filter.save
        format.html { redirect_to campaign_source_filters_path(@campaign), notice: 'Source filter was successfully created.' }
        format.json { render :show, status: :created, location: [@campaign, @source_filter] }
      else
        @fields = @campaign.campaign_fields.ordered.map { |field| [field.label || field.name, field.id] }
        @operators = Filter::OPERATORS.map { |key, value| [key.to_s.titleize, value] }
        @sources = @campaign.sources.active
        format.html { render :new }
        format.json { render json: @source_filter.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def update
    respond_to do |format|
      if @source_filter.update(source_filter_params)
        format.html { redirect_to campaign_source_filters_path(@campaign), notice: 'Source filter was successfully updated.' }
        format.json { render :show, status: :ok, location: [@campaign, @source_filter] }
      else
        @fields = @campaign.campaign_fields.ordered.map { |field| [field.label || field.name, field.id] }
        @operators = Filter::OPERATORS.map { |key, value| [key.to_s.titleize, value] }
        @sources = @campaign.sources.active
        format.html { render :edit }
        format.json { render json: @source_filter.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def destroy
    @source_filter.destroy
    respond_to do |format|
      format.html { redirect_to campaign_source_filters_path(@campaign), notice: 'Source filter was successfully destroyed.' }
      format.json { head :no_content }
    end
  end
  
  private
  
  def set_campaign
    @campaign = current_account.campaigns.find(params[:campaign_id])
  end
  
  def set_source_filter
    @source_filter = @campaign.source_filters.find_by(id: params[:id])
  end
  
  def source_filter_params
    params.require(:source_filter).permit(
      :campaign_field_id, 
      :operator, 
      :value, 
      :min_value, 
      :max_value, 
      :status, 
      :apply_to_all,
      source_ids: []
    )
  end
end