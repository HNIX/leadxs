class SourcesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_source, only: [:show, :edit, :update, :destroy]
  before_action :set_campaign, only: [:index, :new, :create], if: -> { params[:campaign_id].present? }

  # GET /sources or GET /campaigns/:campaign_id/sources
  def index
    # Start with a base scope
    sources = if params[:campaign_id].present?
                # For campaign-specific listing
                @campaign.sources.includes(:company)
              else
                # For global sources listing
                Source.includes(:company, :campaign)
              end
    
    # Apply filters
    if params[:query].present?
      sources = sources.where("sources.name ILIKE ?", "%#{params[:query]}%")
    end
    
    if params[:company_id].present?
      sources = sources.where(company_id: params[:company_id])
    end
    
    if params[:campaign_id].present?
      sources = sources.where(campaign_id: params[:campaign_id])
    end
    
    if params[:status].present?
      sources = sources.where(status: params[:status])
    end
    
    if params[:integration_type].present?
      sources = sources.where(integration_type: params[:integration_type])
    end
    
    if params[:sort].present?
      case params[:sort]
      when 'name_asc'
        sources = sources.order(name: :asc)
      when 'name_desc'
        sources = sources.order(name: :desc)
      when 'newest'
        sources = sources.order(created_at: :desc)
      when 'oldest'
        sources = sources.order(created_at: :asc)
      when 'company'
        sources = sources.joins(:company).order('companies.name ASC')
      end
    else
      # Default sort
      sources = sources.order(created_at: :desc)
    end
    
    # Get summary metrics
    @total_sources = sources.count
    @active_sources = sources.active.count
    @paused_sources = sources.paused.count
    @archived_sources = sources.archived.count
    
    # Get companies and campaigns for filters
    @companies = Company.order(:name)
    @campaigns = Campaign.order(:name)
    
    # Paginate the results
    @pagy, @sources = pagy(sources, items: params[:per_page] || 20)
    
    # Store filters in session for persistence
    session[:sources_filters] = {
      query: params[:query],
      company_id: params[:company_id],
      campaign_id: params[:campaign_id],
      status: params[:status],
      integration_type: params[:integration_type],
      sort: params[:sort],
      per_page: params[:per_page]
    }
    
    # Render the campaign-specific view if in campaign context
    if params[:campaign_id].present?
      render :campaign_sources
    end
  end
  

  # GET /sources/:id
  def show
    # Load leads associated with this source (paginated)
    @pagy, @leads = pagy(@source.leads.order(created_at: :desc), items: 10)
    
    # Fetch metrics
    @total_leads = @source.leads.count
    @leads_last_30_days = @source.leads.where("created_at >= ?", 30.days.ago).count
    @leads_last_7_days = @source.leads.where("created_at >= ?", 7.days.ago).count
    @leads_today = @source.leads.where("created_at >= ?", Date.today.beginning_of_day).count
  end

  # GET /sources/new or GET /campaigns/:campaign_id/sources/new
  def new
    if params[:campaign_id].present?
      @source = @campaign.sources.new
    else
      @source = Source.new
      @campaigns = Campaign.order(:name)
    end
    
    @companies = Company.order(:name)
    
    # If this is a turbo_frame request, render the modal
    if turbo_frame_request?
      render partial: "source_modal", locals: { source: @source }
    end
  end

  # GET /sources/:id/edit
  def edit
    @companies = Company.order(:name)
    # We don't allow changing the campaign once a source is created
  end

  # POST /sources or POST /campaigns/:campaign_id/sources
  def create
    if params[:campaign_id].present?
      @source = @campaign.sources.new(source_params)
    else
      @source = Source.new(source_params)
      # Make sure a campaign_id is provided in the form
      if @source.campaign_id.blank?
        @campaigns = Campaign.order(:name)
        @companies = Company.order(:name)
        flash.now[:alert] = "Campaign is required"
        return render :new, status: :unprocessable_entity
      end
    end
    
    # Handle draft status if present
    is_draft = params[:source][:draft] == "true"
    @source.status = "draft" if is_draft
    
    if @source.save
      if is_draft
        redirect_to source_path(@source), notice: "Source was saved as draft. You can complete setup later."
      else
        redirect_to source_path(@source), notice: "Source was successfully created."
      end
    else
      @campaigns = Campaign.order(:name) unless params[:campaign_id].present?
      @companies = Company.order(:name)
      
      if turbo_frame_request?
        render partial: "source_modal", locals: { source: @source }, status: :unprocessable_entity
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  # PATCH/PUT /sources/:id
  def update
    respond_to do |format|
      if @source.update(source_params)
        format.html { redirect_to source_path(@source), notice: "Source was successfully updated." }
        format.json { render :show, status: :ok, location: @source }
        format.turbo_stream
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @source.errors, status: :unprocessable_entity }
      end
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
  
  # POST /sources/bulk_update
  def bulk_update
    # Get the source ids and action from the params
    source_ids = params[:source_ids] || []
    action = params[:bulk_action]
    
    if source_ids.empty?
      redirect_to sources_path, alert: "No sources selected"
      return
    end
    
    # Find the sources to update
    sources = Source.where(id: source_ids)
    
    # Apply the appropriate action
    case action
    when "activate"
      sources.update_all(status: "active")
      flash[:notice] = "#{sources.count} sources activated"
    when "pause"
      sources.update_all(status: "paused")
      flash[:notice] = "#{sources.count} sources paused"
    when "archive"
      sources.update_all(status: "archived")
      flash[:notice] = "#{sources.count} sources archived"
    else
      flash[:alert] = "Unknown action: #{action}"
    end
    
    # Redirect back to the sources page
    redirect_to sources_path(params.permit(:query, :company_id, :campaign_id, :status, :integration_type, :sort, :per_page))
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
      :company_id,
      :campaign_id,
      :webhook_url,
      :webhook_secret,
      :success_postback_url,
      :failure_postback_url,
      :ip_whitelist,
      :allowed_domains
    )
  end
end