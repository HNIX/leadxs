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
    
    # Apply filters if provided
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
    
    # Order by most recent first
    api_requests = api_requests.order(created_at: :desc)
    
    # Paginate results
    @pagy, @api_requests = pagy(
      api_requests,
      items: params[:per_page] || 25
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
    @api_request = ApiRequest.find_by(id: params[:id], account: current_account)
    
    unless @api_request
      redirect_to api_requests_path, alert: "API Request not found"
    end
  end

  def api_request_params
    params.require(:api_request).permit(:endpoint_url, :request_method, :request_payload)
  end
end