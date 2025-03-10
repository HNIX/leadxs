class ComplianceController < ApplicationController
  include Pagy::Backend
  
  before_action :authenticate_user!
  before_action :set_record, only: [:show, :history, :consent, :export]
  before_action :authorize_compliance, except: [:index, :dashboard]
  
  def index
    # Initialize the query with the base scope
    # Explicitly set the account to ensure proper tenant scoping
    query = ComplianceRecord.where(account_id: current_account.id).order(occurred_at: :desc)
    
    # Apply event type filter if provided
    if params[:event_type].present? && params[:event_type] != ""
      query = query.of_type(params[:event_type])
    end
    
    # Apply action filter if provided
    if params[:action_type].present? && params[:action_type] != ""
      query = query.with_action(params[:action_type])
    end
    
    # Apply date range filter if provided
    if params[:start_date].present? && params[:end_date].present?
      begin
        start_date = Date.parse(params[:start_date].to_s).beginning_of_day
        end_date = Date.parse(params[:end_date].to_s).end_of_day
        query = query.in_range(start_date, end_date)
      rescue => e
        # Log error but continue without the date filter
        Rails.logger.warn("Date filter error: #{e.message}")
        flash.now[:alert] = "Invalid date format. Date filter has been ignored."
      end
    end
    
    # Ensure we have records for pagination
    if query.exists?
      @pagy, @compliance_records = pagy(query, items: 50)
    else
      # If no records found with filters, show a message but don't apply filters
      flash.now[:notice] = "No records found with the selected filters. Showing all records."
      @pagy, @compliance_records = pagy(ComplianceRecord.where(account_id: current_account.id).order(occurred_at: :desc), items: 50)
    end
  end
  
  def dashboard
    # Summary statistics for compliance dashboard
    @report_data = compliance_service.generate_compliance_report(30.days.ago, Time.current)
    
    # Recent compliance events
    @recent_events = ComplianceRecord.order(occurred_at: :desc).limit(10)
    
    # Recent consent records
    @recent_consents = ConsentRecord.order(created_at: :desc).limit(10)
    
    # Recent data access events
    @recent_access = DataAccessRecord.order(accessed_at: :desc).limit(10)
  end
  
  def show
    # Record access to this record for compliance tracking
    record_data_access(@record, DataAccessRecord::VIEW, {
      purpose: "Compliance Verification",
      context: DataAccessRecord::COMPLIANCE
    })
    
    # Get compliance data for this record
    query = compliance_service.compliance_history(@record)
    @pagy, @compliance_history = pagy(query, items: 20)
  end

  def history
    # Filter parameters
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
    @event_type = params[:event_type]
    @action = params[:action_type]
    
    # Get filtered compliance history
    query = compliance_service.compliance_history(@record, {
      start_date: @start_date,
      end_date: @end_date,
      event_type: @event_type,
      action: @action
    })
    
    @pagy, @compliance_history = pagy(query, items: 50)
  end

  def report
    # Date range for report
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
    
    # Generate compliance report
    @report = compliance_service.generate_compliance_report(@start_date, @end_date)
    
    respond_to do |format|
      format.html
      format.json { render json: @report }
      format.pdf do
        # This would generate a PDF in a real implementation
        # For now, we'll just render JSON
        render json: @report
      end
    end
  end

  def consent
    if request.post?
      # Create a new consent record
      @consent = @record.record_consent(
        params[:consent_type],
        params[:consent_text],
        {
          ip_address: request.ip,
          user_agent: request.user_agent,
          expires_at: params[:expires_at].present? ? Date.parse(params[:expires_at]) : nil,
          metadata: { source: "admin_panel", admin_user_id: current_user.id }
        }
      )
      
      redirect_to compliance_show_path(record_type: @record.class.name.underscore, record_id: @record.id),
                  notice: "Consent record created successfully."
    elsif request.delete?
      # Revoke consent
      @consent = @record.consent_records.find(params[:consent_id])
      @consent.revoke!(params[:revocation_reason])
      
      redirect_to compliance_show_path(record_type: @record.class.name.underscore, record_id: @record.id),
                  notice: "Consent has been revoked."
    else
      # Show consent form
      @consents = @record.consent_records.order(created_at: :desc)
      @consent_types = [
        ConsentRecord::DISTRIBUTION_CONSENT,
        ConsentRecord::MARKETING_CONSENT,
        ConsentRecord::TERMS_OF_SERVICE,
        ConsentRecord::PRIVACY_POLICY,
        ConsentRecord::DATA_SHARING
      ]
    end
  end

  def export
    # Generate a detailed compliance report for this record
    @report = @record.generate_compliance_report
    
    # Record this export for compliance purposes
    record_data_access(@record, DataAccessRecord::EXPORT, {
      purpose: "Compliance Export",
      context: DataAccessRecord::COMPLIANCE
    })
    
    respond_to do |format|
      format.html
      format.json { render json: @report }
      format.pdf do
        # This would generate a PDF in a real implementation
        # For now, we'll just render JSON
        render json: @report
      end
    end
  end
  
  # Generate a signed regulatory report
  def regulatory_report
    authorize :compliance, :regulatory_access?
    
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
    
    # Generate the report
    begin
      @report = compliance_service.generate_regulatory_report({
        start_date: @start_date,
        end_date: @end_date
      })
    rescue => e
      # If there's an error, create a basic report
      Rails.logger.error("Error generating regulatory report: #{e.message}")
      @report = {
        error: "Error generating report: #{e.message}",
        report_id: SecureRandom.uuid,
        generated_at: Time.current.iso8601
      }
    end
    
    # Generate a report ID if not present
    report_id = @report&.dig(:report_id) || SecureRandom.uuid
    
    # Record this access
    ComplianceRecord.create_record(
      record: current_account,
      event_type: ComplianceRecord::SYSTEM,
      action: "regulatory_report_generated",
      data: { 
        report_id: report_id,
        date_range: "#{@start_date&.to_s || 'unknown'} to #{@end_date&.to_s || 'unknown'}" 
      },
      user: current_user,
      request: request
    )
    
    respond_to do |format|
      format.html
      format.json { render json: @report }
      format.pdf do
        # This would generate a PDF in a real implementation
        # For now, we'll just render JSON
        render json: @report
      end
    end
  end
  
  # Exposing the compliance_service as a helper method for views
  helper_method :compliance_service
  
  private
  
  def set_record
    record_type = params[:record_type].classify
    record_id = params[:record_id]
    
    # Validate record type is allowed
    allowed_types = ["Lead", "ConsentRecord", "Distribution", "BidRequest", "ComplianceRecord", "Account"]
    unless allowed_types.include?(record_type)
      redirect_to root_path, alert: "Invalid record type."
      return
    end
    
    # Find the record
    @record = record_type.constantize.find_by(id: record_id)
    
    unless @record
      redirect_to root_path, alert: "Record not found."
      return
    end
    
    # Check tenant access
    if @record.is_a?(Account)
      # For Account records, verify it's the current account
      unless @record.id == current_account.id
        redirect_to root_path, alert: "You don't have access to this record."
        return
      end
    else
      # For other records, check the account_id
      unless @record.account_id == current_account.id
        redirect_to root_path, alert: "You don't have access to this record."
        return
      end
    end
  end
  
  def authorize_compliance
    authorize :compliance, :access?
  end
  
  def compliance_service
    @compliance_service ||= ComplianceService.new(
      account: current_account,
      user: current_user,
      request: request
    )
  end
  
  def record_data_access(record, action, options = {})
    DataAccessRecord.record_access(
      record,
      action,
      current_user,
      options.merge(
        ip_address: request.ip,
        user_agent: request.user_agent
      )
    )
  end
end
