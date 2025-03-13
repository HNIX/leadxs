class LeadsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_lead, only: [:show, :journey]

  def index
    # Start with base scope
    leads = Lead.all
    
    # Apply ID search if provided
    if params[:unique_id].present?
      leads = leads.where("unique_id ILIKE ?", "%#{params[:unique_id]}%")
    end
    
    # Apply other filters if provided
    leads = leads.where(campaign_id: params[:campaign_id]) if params[:campaign_id].present?
    leads = leads.where(source_id: params[:source_id]) if params[:source_id].present?
    
    # Handle status filters, with special handling for 'new' to match 'new_lead'
    if params[:status].present?
      if params[:status] == 'new'
        leads = leads.where(status: 'new_lead')
      else
        leads = leads.where(status: params[:status])
      end
    end
    
    # Apply date range filters if provided
    if params[:created_after].present?
      date = Date.parse(params[:created_after]) rescue nil
      leads = leads.where("created_at >= ?", date.beginning_of_day) if date
    end
    
    if params[:created_before].present?
      date = Date.parse(params[:created_before]) rescue nil
      leads = leads.where("created_at <= ?", date.end_of_day) if date
    end
    
    # Apply sorting
    if params[:sort_by] == 'oldest'
      leads = leads.order(created_at: :asc)
    else
      # Default to newest first
      # Add ID as secondary sort to ensure consistent ordering
      leads = leads.order(created_at: :desc, id: :desc)
    end
    
    # Paginate results
    per_page = params[:per_page].present? ? params[:per_page].to_i : 20
    @pagy, @leads = pagy(leads, limit: per_page)

    respond_to do |format|
      format.html
      format.json { render :index }
    end
  end

  def show
    @lead_data = @lead.lead_data.includes(:campaign_field).order("campaign_fields.position")
    @api_requests = @lead.api_requests.order(created_at: :desc)
    
    # Load bid request and bids information
    @bid_request = @lead.bid_request || @lead.generated_bid_request
    @bids = @bid_request ? @bid_request.bids.includes(:distribution).order(created_at: :desc) : []
    @winning_bid = @bid_request&.winning_bid
    
    # We don't need to load all activities here since the view only shows the most recent 5
    # This will be handled by the lead association

    respond_to do |format|
      format.html
      format.json { render :show }
    end
  end

  def journey
    # Get the lead's full journey history
    @activities = @lead.lead_activity_logs.includes(:user, :causer).chronological
    
    # Get all associated bid requests
    @bid_request = @lead.bid_request || @lead.generated_bid_request
    
    # Get all bids
    @bids = @bid_request ? @bid_request.bids.includes(:distribution).order(created_at: :desc) : []
    
    # Get all API requests
    @api_requests = @lead.api_requests.includes(:requestable).order(created_at: :desc)
    
    # Get all compliance records
    @compliance_records = @lead.compliance_records.order(occurred_at: :desc)
    @consent_records = @lead.consent_records.order(consented_at: :desc)
    @data_access_records = @lead.data_access_records.order(accessed_at: :desc)
    
    # Track this view in the data access log
    if defined?(DataAccessRecord) && defined?(ComplianceService)
      DataAccessRecord.record_access(@lead, 'view', current_user, {
        access_context: 'journey_view',
        purpose: 'Lead journey analysis',
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      })
    end
    
    respond_to do |format|
      format.html
      format.json
    end
  end
  
  private

  def set_lead
    @lead = Lead.find_by(id: params[:id], account: current_account)
    
    unless @lead
      redirect_to leads_path, alert: "Lead not found"
    end
  end
end