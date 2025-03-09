class DistributionFiltersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_campaign
  before_action :set_distribution_filter, only: [:show, :edit, :update, :destroy]
  
  def index
    @distribution_filters = @campaign.distribution_filters.includes(:campaign_field, :distributions).where(type: 'DistributionFilter')
    @fields = @campaign.campaign_fields.ordered.map { |field| [field.label || field.name, field.id] }
    @operators = Filter::OPERATORS.map { |key, value| [key.to_s.titleize, value] }
    @distributions = @campaign.distributions.active
  end
  
  def show
  end
  
  def new
    @distribution_filter = DistributionFilter.new(status: 'active', apply_to_all: true, campaign: @campaign, account: current_account)
    @fields = @campaign.campaign_fields.ordered.map { |field| [field.label || field.name, field.id] }
    @operators = Filter::OPERATORS.map { |key, value| [key.to_s.titleize, value] }
    @distributions = @campaign.distributions.active
  end
  
  def edit
    @fields = @campaign.campaign_fields.ordered.map { |field| [field.label || field.name, field.id] }
    @operators = Filter::OPERATORS.map { |key, value| [key.to_s.titleize, value] }
    @distributions = @campaign.distributions.active
  end
  
  def create
    @distribution_filter = DistributionFilter.new(distribution_filter_params)
    @distribution_filter.campaign = @campaign
    @distribution_filter.account = current_account
    @distribution_filter.type = 'DistributionFilter'
    
    respond_to do |format|
      if @distribution_filter.save
        format.html { redirect_to campaign_distribution_filters_path(@campaign), notice: 'Distribution filter was successfully created.' }
        format.json { render :show, status: :created, location: [@campaign, @distribution_filter] }
      else
        @fields = @campaign.campaign_fields.ordered.map { |field| [field.label || field.name, field.id] }
        @operators = Filter::OPERATORS.map { |key, value| [key.to_s.titleize, value] }
        @distributions = @campaign.distributions.active
        format.html { render :new }
        format.json { render json: @distribution_filter.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def update
    respond_to do |format|
      if @distribution_filter.update(distribution_filter_params)
        format.html { redirect_to campaign_distribution_filters_path(@campaign), notice: 'Distribution filter was successfully updated.' }
        format.json { render :show, status: :ok, location: [@campaign, @distribution_filter] }
      else
        @fields = @campaign.campaign_fields.ordered.map { |field| [field.label || field.name, field.id] }
        @operators = Filter::OPERATORS.map { |key, value| [key.to_s.titleize, value] }
        @distributions = @campaign.distributions.active
        format.html { render :edit }
        format.json { render json: @distribution_filter.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def destroy
    @distribution_filter.destroy
    respond_to do |format|
      format.html { redirect_to campaign_distribution_filters_path(@campaign), notice: 'Distribution filter was successfully destroyed.' }
      format.json { head :no_content }
    end
  end
  
  private
  
  def set_campaign
    @campaign = current_account.campaigns.find(params[:campaign_id])
  end
  
  def set_distribution_filter
    @distribution_filter = @campaign.distribution_filters.find_by(id: params[:id])
  end
  
  def distribution_filter_params
    params.require(:distribution_filter).permit(
      :campaign_field_id, 
      :operator, 
      :value, 
      :min_value, 
      :max_value, 
      :status, 
      :apply_to_all,
      distribution_ids: []
    )
  end
end