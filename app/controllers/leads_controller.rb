class LeadsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_lead, only: [:show]

  def index
    # Start with base scope
    leads = Lead.where(account: current_account)
    
    # Apply ID search if provided
    if params[:unique_id].present?
      leads = leads.where("unique_id ILIKE ?", "%#{params[:unique_id]}%")
    end
    
    # Apply other filters if provided
    leads = leads.where(campaign_id: params[:campaign_id]) if params[:campaign_id].present?
    leads = leads.where(source_id: params[:source_id]) if params[:source_id].present?
    leads = leads.where(status: params[:status]) if params[:status].present?
    
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
      leads = leads.order(created_at: :desc)
    end
    
    # Paginate results
    per_page = params[:per_page].present? ? params[:per_page].to_i : 5
    @pagy, @leads = pagy(leads, limit: per_page)

    respond_to do |format|
      format.html
      format.json { render :index }
    end
  end

  def show
    @lead_data = @lead.lead_data.includes(:campaign_field).order("campaign_fields.position")
    @api_requests = @lead.api_requests.order(created_at: :desc)
    
    # We don't need to load all activities here since the view only shows the most recent 5
    # This will be handled by the lead association

    respond_to do |format|
      format.html
      format.json { render :show }
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