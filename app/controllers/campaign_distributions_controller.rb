class CampaignDistributionsController < ApplicationController
  before_action :set_campaign, only: [:index, :new, :create]
  before_action :set_campaign_distribution, only: [:show, :edit, :update, :destroy]

  def index
    @campaign_distributions = @campaign.campaign_distributions.includes(:distribution)
  end

  def new
    @campaign_distribution = @campaign.campaign_distributions.new
    @distributions = available_distributions
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    @campaign_distribution = @campaign.campaign_distributions.new(campaign_distribution_params)

    respond_to do |format|
      if @campaign_distribution.save
        format.html { 
          redirect_to configure_campaign_path(@campaign, anchor: 'distribution'), 
          notice: "Distribution was successfully added to campaign." 
        }
        format.turbo_stream { 
          redirect_to configure_campaign_path(@campaign, anchor: 'distribution'),
          notice: "Distribution was successfully added to campaign."
        }
        format.json { render :show, status: :created, location: @campaign_distribution }
      else
        @distributions = available_distributions
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
        format.json { render json: @campaign_distribution.errors, status: :unprocessable_entity }
      end
    end
  end

  def show
    @mapped_fields = @campaign_distribution.mapped_fields
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def edit
    @campaign = @campaign_distribution.campaign
    @distributions = available_distributions_for_edit
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def update
    respond_to do |format|
      if @campaign_distribution.update(campaign_distribution_params)
        format.html { 
          redirect_to configure_campaign_path(@campaign_distribution.campaign, anchor: 'distribution'), 
          notice: "Campaign distribution was successfully updated." 
        }
        format.turbo_stream { 
          redirect_to configure_campaign_path(@campaign_distribution.campaign, anchor: 'distribution'),
          notice: "Campaign distribution was successfully updated."
        }
        format.json { render :show, status: :ok, location: @campaign_distribution }
      else
        @campaign = @campaign_distribution.campaign
        @distributions = available_distributions_for_edit
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
        format.json { render json: @campaign_distribution.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    campaign = @campaign_distribution.campaign
    @campaign_distribution.destroy

    respond_to do |format|
      format.html { 
        redirect_to configure_campaign_path(campaign, anchor: 'distribution'), 
        notice: "Distribution was successfully removed from campaign." 
      }
      format.turbo_stream { 
        redirect_to configure_campaign_path(campaign, anchor: 'distribution'),
        notice: "Distribution was successfully removed from campaign."
      }
      format.json { head :no_content }
    end
  end

  private

  def set_campaign
    @campaign = Campaign.find(params[:campaign_id])
  end

  def set_campaign_distribution
    @campaign_distribution = CampaignDistribution.find(params[:id])
  end

  def campaign_distribution_params
    params.require(:campaign_distribution).permit(:distribution_id, :active, :priority)
  end

  def available_distributions
    # Get all active distributions that are not already associated with this campaign
    associated_distribution_ids = @campaign.distributions.pluck(:id)
    current_account.companies.includes(:distributions)
                   .flat_map { |company| company.distributions.active }
                   .reject { |distribution| associated_distribution_ids.include?(distribution.id) }
                   .sort_by(&:name)
  end

  def available_distributions_for_edit
    # For edit, we need to include the current distribution in the list
    associated_distribution_ids = @campaign.distributions.where.not(id: @campaign_distribution.distribution_id).pluck(:id)
    current_account.companies.includes(:distributions)
                   .flat_map { |company| company.distributions.active }
                   .reject { |distribution| associated_distribution_ids.include?(distribution.id) }
                   .sort_by(&:name)
  end
end
