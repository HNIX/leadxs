class CampaignsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_campaign, only: [:show, :edit, :update, :destroy, :sync_vertical_fields, :configure]
  before_action :set_verticals, only: [:new, :create, :edit, :update, :configure]

  def index
    # Start with base scope
    campaigns = Campaign.includes(:vertical, :campaign_fields, :sources, :distributions)
    
    # Apply search filter if provided
    if params[:name].present?
      campaigns = campaigns.where("name ILIKE ?", "%#{params[:name]}%")
    end
    
    # Apply vertical filter if provided
    if params[:vertical_id].present?
      campaigns = campaigns.where(vertical_id: params[:vertical_id])
    end
    
    # Apply status filter if provided
    if params[:status].present?
      campaigns = campaigns.where(status: params[:status])
    end
    
    # Apply campaign type filter if provided
    if params[:campaign_type].present?
      campaigns = campaigns.where(campaign_type: params[:campaign_type])
    end
    
    # Apply distribution method filter if provided
    if params[:distribution_method].present?
      campaigns = campaigns.where(distribution_method: params[:distribution_method])
    end
    
    # Apply date range filters if provided
    if params[:created_after].present?
      date = Date.parse(params[:created_after]) rescue nil
      campaigns = campaigns.where("created_at >= ?", date.beginning_of_day) if date
    end
    
    if params[:created_before].present?
      date = Date.parse(params[:created_before]) rescue nil
      campaigns = campaigns.where("created_at <= ?", date.end_of_day) if date
    end
    
    # Apply sorting
    if params[:sort_by] == 'oldest'
      campaigns = campaigns.order(created_at: :asc)
    elsif params[:sort_by] == 'name_asc'
      campaigns = campaigns.order(name: :asc)
    elsif params[:sort_by] == 'name_desc'
      campaigns = campaigns.order(name: :desc)
    else
      # Default to newest first
      campaigns = campaigns.order(created_at: :desc)
    end
    
    # Paginate results
    per_page = params[:per_page].present? ? params[:per_page].to_i : 10
    @pagy, @campaigns = pagy(campaigns, items: per_page)
    
    # Store the total count for use in the view
    @total_campaigns_count = @pagy.count
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
    @validation_rules = @campaign.validation_rules.ordered
    @source_filters = @campaign.source_filters.where(type: 'SourceFilter').includes(:campaign_field).limit(5)
    @distribution_filters = @campaign.distribution_filters.where(type: 'DistributionFilter').includes(:campaign_field).limit(5)
    @sources = @campaign.sources.includes(:company).limit(5)
    @distributions = @campaign.distributions.includes(:company).limit(5)
    @leads_count = @campaign.leads.count
    @recent_leads = @campaign.leads.order(created_at: :desc).limit(5)
    
    # Get bidding analytics for this campaign
    @period_type = params[:period_type] || 'daily'
    @date_range = get_date_range(@period_type)
    
    @bid_analytics = BidAnalyticSnapshot
                      .for_campaign(@campaign.id)
                      .where(period_type: @period_type)
                      .where("period_start >= ? AND period_end <= ?", @date_range[:start], @date_range[:end])
                      .order(period_start: :desc)
                      .limit(5)
    
    # Calculate summary metrics
    @bid_metrics = calculate_bid_metrics(@bid_analytics)
  end
  
  def configure
    @campaign = Campaign.find(params[:id])
    @section = params[:section] || 'fields'
    @subsection = params[:subsection]
    
    # Load campaign fields for all sections
    @pagy, @campaign_fields = pagy(@campaign.campaign_fields.ordered, items: 15)
    
    # Load calculated fields for all sections
    @calculated_fields = @campaign.calculated_fields.ordered
    
    # Load validation rules for all sections
    @validation_rules = @campaign.validation_rules.ordered
    
    # Load sources and distributions for all sections
    @sources = @campaign.sources.includes(:company)
    @distributions = @campaign.distributions.includes(:company)
    
    # Load filters for all sections
    @source_filters = @campaign.source_filters.where(type: 'SourceFilter').includes(:campaign_field)
    @distribution_filters = @campaign.distribution_filters.where(type: 'DistributionFilter').includes(:campaign_field)
    
    # Handle legacy URLs
    case @section
    when 'calculated_fields', 'source_filters', 'distribution_filters'
      # Redirect legacy URLs to the new consolidated sections
      new_section = case @section
                    when 'calculated_fields' then 'fields'
                    when 'source_filters' then 'sources'
                    when 'distribution_filters' then 'distributions'
                    end
      redirect_to configure_campaign_path(@campaign, section: new_section, subsection: @section)
      return
    end
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
  
  def sync_vertical_fields
    if @campaign.vertical.present?
      # Use the CampaignFieldGenerator service to sync vertical fields
      synced_count = CampaignFieldGenerator.new(@campaign).sync_vertical_fields
      
      if synced_count > 0
        redirect_to campaign_campaign_fields_path(@campaign), notice: "#{synced_count} vertical fields were successfully synchronized with this campaign."
      else
        redirect_to campaign_campaign_fields_path(@campaign), notice: "No fields needed synchronization. All vertical fields are already present."
      end
    else
      redirect_to campaign_campaign_fields_path(@campaign), alert: "Cannot sync fields: this campaign does not have a vertical assigned."
    end
  end

  private
  
  def get_date_range(period_type)
    case period_type
    when 'hourly'
      end_date = Time.current
      start_date = end_date - 24.hours
    when 'daily'
      end_date = Date.current.end_of_day
      start_date = (end_date - 7.days).beginning_of_day
    when 'weekly'
      end_date = Date.current.end_of_week.end_of_day
      start_date = (end_date - 4.weeks).beginning_of_week.beginning_of_day
    when 'monthly'
      end_date = Date.current.end_of_month.end_of_day
      start_date = (end_date - 3.months).beginning_of_month.beginning_of_day
    else
      end_date = Date.current.end_of_day
      start_date = (end_date - 7.days).beginning_of_day
    end
    
    { start: start_date, end: end_date }
  end
  
  def calculate_bid_metrics(snapshots)
    return {} if snapshots.empty?
    
    total_bids = snapshots.sum(:total_bids)
    accepted_bids = snapshots.sum(:accepted_bids)
    avg_bid_amount = snapshots.sum { |s| s.avg_bid_amount * s.total_bids } / [total_bids, 1].max
    
    {
      total_bids: total_bids,
      accepted_bids: accepted_bids,
      acceptance_rate: total_bids > 0 ? (accepted_bids.to_f / total_bids * 100).round(2) : 0,
      avg_bid_amount: avg_bid_amount.round(2),
      total_revenue: snapshots.sum(:total_revenue).round(2),
      conversion_count: snapshots.sum(:conversion_count)
    }
  end

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
      :bid_timeout_seconds,
      :minimum_bid_amount,
      :multi_distribution_strategy,
      :max_distributions,
      distribution_schedule_days: []
    )
  end
end
