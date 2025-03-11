class LeadActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_lead
  before_action :authorize_lead_access
  
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  
  def index
    @pagy, @activities = pagy(filtered_activities, items: params[:per_page] || 15)
    respond_to do |format|
      format.html
      format.json { render json: @activities }
      format.turbo_stream if turbo_frame_request?
    end
  end
  
  def show
    @activity = @lead.lead_activity_logs.find_by(id: params[:id], account: current_account)
    redirect_to lead_activities_path(@lead), alert: "Activity log not found" unless @activity
  end
  
  private
  
  def set_lead
    @lead = Lead.find_by(id: params[:lead_id], account: current_account)
    redirect_to leads_path, alert: "Lead not found" unless @lead
  end
  
  def authorize_lead_access
    authorize @lead, :show?
  end
  
  def user_not_authorized
    redirect_to leads_path, alert: "You are not authorized to view this lead's activities."
  end
  
  def filtered_activities
    activities = @lead.lead_activity_logs.includes(:user, :causer)
    
    # Filter by activity type if specified
    if params[:activity_type].present?
      activities = activities.with_type(params[:activity_type])
    end
    
    # Filter by date range if specified
    if params[:start_date].present? && params[:end_date].present?
      begin
        start_date = Date.parse(params[:start_date]).beginning_of_day
        end_date = Date.parse(params[:end_date]).end_of_day
        activities = activities.timeframe(start_date, end_date)
      rescue ArgumentError
        # Invalid date format, ignore filter
      end
    end
    
    # Order by timestamp, default to recent first
    if params[:order] == 'oldest'
      activities.chronological
    else
      activities.recent_first
    end
  end
end