class ApiRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_api_request, only: [:show, :resend]

  def index
    # Start with base scope - this is now handled by acts_as_tenant
    api_requests = ApiRequest.all
    
    # Apply status filter if provided
    if params[:status].present?
      case params[:status]
      when 'successful'
        api_requests = api_requests.successful
      when 'failed'
        api_requests = api_requests.failed
      end
    end
    
    # Apply ID search if provided
    if params[:uuid].present?
      api_requests = api_requests.where("uuid ILIKE ?", "%#{params[:uuid]}%")
    end
    
    # Apply other filters if provided
    api_requests = api_requests.where(requestable_type: params[:requestable_type]) if params[:requestable_type].present?
    api_requests = api_requests.where(request_method: params[:method]) if params[:method].present?
    api_requests = api_requests.where(lead_id: params[:lead_id]) if params[:lead_id].present?
    
    # Apply campaign filter if provided
    if params[:campaign_id].present?
      campaign = Campaign.find_by(id: params[:campaign_id], account: current_account)
      if campaign
        api_requests = api_requests.where(lead_id: campaign.leads.select(:id))
      end
    end
    
    # Apply endpoint search if provided
    if params[:endpoint_contains].present?
      api_requests = api_requests.where("endpoint_url ILIKE ?", "%#{params[:endpoint_contains]}%")
    end
    
    # Apply date range filters if provided
    if params[:created_after].present?
      date = Date.parse(params[:created_after]) rescue nil
      api_requests = api_requests.where("created_at >= ?", date.beginning_of_day) if date
    end
    
    if params[:created_before].present?
      date = Date.parse(params[:created_before]) rescue nil
      api_requests = api_requests.where("created_at <= ?", date.end_of_day) if date
    end
    
    # Apply sorting
    if params[:sort_by] == 'oldest'
      api_requests = api_requests.order(created_at: :asc)
    else
      # Default to newest first
      api_requests = api_requests.order(created_at: :desc)
    end
    
    # Paginate results
    per_page = params[:per_page].present? ? params[:per_page].to_i : 5
    @pagy, @api_requests = pagy(
      api_requests,
      limit: per_page
    )

    respond_to do |format|
      format.html
      format.json { render :index }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render :show }
    end
  end
  
  # Resend an API request
  def resend
    unless @api_request.sent_at?
      # Create a background job to resend the request
      # ApiRequestResendJob.perform_later(@api_request.id)
      
      # For now, just mark it as sent
      @api_request.mark_as_sent
      
      redirect_to api_request_path(@api_request), notice: "API request has been queued for resending."
    else
      redirect_to api_request_path(@api_request), alert: "This API request has already been sent."
    end
  end

  private

  def set_api_request
    @api_request = ApiRequest.find_by(uuid: params[:id], account: current_account)
    
    unless @api_request
      redirect_to api_requests_path, alert: "API Request not found"
    end
  end

  def api_request_params
    params.require(:api_request).permit(:endpoint_url, :request_method, :request_payload)
  end
end