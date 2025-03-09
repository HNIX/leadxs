class LeadsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_lead, only: [:show]

  def index
    # Start with base scope
    leads = Lead.where(account: current_account)
    
    # Apply filters if provided
    leads = leads.where(campaign_id: params[:campaign_id]) if params[:campaign_id].present?
    leads = leads.where(source_id: params[:source_id]) if params[:source_id].present?
    leads = leads.where(status: params[:status]) if params[:status].present?
    
    # Order by most recent first
    leads = leads.order(created_at: :desc)
    
    # Paginate results
    @pagy, @leads = pagy(leads, items: params[:per_page] || 25)

    respond_to do |format|
      format.html
      format.json { render :index }
    end
  end

  def show
    @lead_data = @lead.lead_data.includes(:campaign_field).order("campaign_fields.position")
    @api_requests = @lead.api_requests.order(created_at: :desc)

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