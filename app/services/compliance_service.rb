require 'securerandom'
require 'openssl'
require 'base64'
require 'digest'

class ComplianceService
  attr_reader :account, :user, :request

  def initialize(account: nil, user: nil, request: nil)
    @account = account || Current.account
    @user = user || Current.user
    @request = request || Current.request
  end

  # Record lead-related compliance events
  def record_lead_processing(lead, action, data = {})
    ComplianceRecord.record_lead_event(lead, action, data, user, request)
  end

  # Record distribution-related compliance events
  def record_distribution(lead, distribution, action, data = {})
    ComplianceRecord.record_distribution_event(lead, distribution, action, data, user, request)
  end

  # Record validation-related compliance events
  def record_validation(lead, action, data = {})
    ComplianceRecord.record_validation_event(lead, action, data, user, request)
  end

  # Record consent-related compliance events
  def record_consent(consent_record, action, data = {})
    ComplianceRecord.record_consent_event(consent_record, action, data, user, request)
  end

  # Record bid-related compliance events
  def record_bid_event(bid_request, action, data = {})
    ComplianceRecord.record_bid_event(bid_request, action, data, user, request)
  end

  # Record data access
  def record_data_access(record, action, options = {})
    DataAccessRecord.record_access(record, action, user, options)
  end

  # Create a consent record for a lead
  def create_consent_record(lead, consent_type, consent_text, options = {})
    ConsentRecord.create!(
      account: account,
      lead: lead,
      user: user,
      consent_type: consent_type,
      consent_text: consent_text,
      ip_address: options[:ip_address] || request&.ip || "127.0.0.1",
      user_agent: options[:user_agent] || request&.user_agent,
      consented_at: options[:consented_at] || Time.current,
      expires_at: options[:expires_at],
      metadata: options[:metadata] || {}
    )
  end

  # Verify if lead has valid consent of specified type
  def has_valid_consent?(lead, consent_type)
    lead.consent_records.active.of_type(consent_type).exists?
  end

  # Get all compliance records for a record
  def compliance_history(record, options = {})
    # Make sure we're scoping to the current account
    query = ComplianceRecord.where(account_id: account.id).for_record(record).order(occurred_at: :desc)
    
    # Apply filters if provided
    query = query.of_type(options[:event_type]) if options[:event_type].present?
    query = query.with_action(options[:action]) if options[:action].present?
    query = query.in_range(options[:start_date], options[:end_date]) if options[:start_date].present? && options[:end_date].present?
    
    # Return the query directly - pagination will be handled in the controller with Pagy
    query
  end

  # Generate compliance report for a period
  def generate_compliance_report(start_date, end_date)
    end_date = end_date.end_of_day
    
    # Get all compliance records in date range scoped to current account
    records = ComplianceRecord.where(account_id: account.id).in_range(start_date, end_date)
    
    # Generate access report
    access_report = DataAccessRecord.generate_access_report(account, start_date, end_date)
    
    # Basic statistics
    report = {
      period_start: start_date,
      period_end: end_date,
      total_compliance_events: records.count,
      events_by_type: {},
      events_by_action: {},
      data_access_report: access_report,
      consent_statistics: {
        consents_given: records.of_type(ComplianceRecord::CONSENT).with_action(ComplianceRecord::CONSENT_GIVEN).count,
        consents_revoked: records.of_type(ComplianceRecord::CONSENT).with_action(ComplianceRecord::CONSENT_REVOKED).count
      },
      distribution_statistics: {
        distributions_attempted: records.of_type(ComplianceRecord::DISTRIBUTION).with_action(ComplianceRecord::DISTRIBUTION_ATTEMPTED).count,
        distributions_succeeded: records.of_type(ComplianceRecord::DISTRIBUTION).with_action(ComplianceRecord::DISTRIBUTION_SUCCEEDED).count,
        distributions_failed: records.of_type(ComplianceRecord::DISTRIBUTION).with_action(ComplianceRecord::DISTRIBUTION_FAILED).count
      }
    }
    
    # Group by event type
    records.group(:event_type).count.each do |event_type, count|
      report[:events_by_type][event_type] = count
    end
    
    # Group by action
    records.group(:action).count.each do |action, count|
      report[:events_by_action][action] = count
    end
    
    report
  end

  # Generate a signed compliance report for regulatory purposes
  def generate_regulatory_report(options = {})
    start_date = options[:start_date] || 30.days.ago.beginning_of_day
    end_date = options[:end_date] || Time.current.end_of_day
    
    begin
      # Generate a detailed compliance report
      report_data = generate_compliance_report(start_date, end_date)
      
      # Add metadata
      report_data[:report_id] = SecureRandom.uuid
      report_data[:generated_at] = Time.current.iso8601
      report_data[:account_id] = account&.id
      report_data[:account_name] = account&.name
      report_data[:generated_by] = user&.name || "System"
      
      # Ensure event_by_type is always a hash
      report_data[:events_by_type] ||= {}
      
      # Sign the report data
      sign_report(report_data)
    rescue => e
      # Return a minimal report with error information if something goes wrong
      {
        error: "Error generating report: #{e.message}",
        report_id: SecureRandom.uuid,
        generated_at: Time.current.iso8601,
        account_id: account&.id,
        account_name: account&.name,
        generated_by: user&.name || "System",
        signature: "ERROR-GENERATING-SIGNATURE",
        signature_algorithm: "HMAC-SHA256",
        signed_at: Time.current.iso8601,
        total_compliance_events: 0,
        events_by_type: {},
        events_by_action: {},
        data_access_report: {},
        consent_statistics: {
          consents_given: 0,
          consents_revoked: 0
        },
        distribution_statistics: {
          distributions_attempted: 0,
          distributions_succeeded: 0,
          distributions_failed: 0
        }
      }
    end
  end

  # Create a pre-signed URL for compliance report access
  def create_report_access_url(report_id, expires_in = 24.hours)
    # In a production system, this might generate a presigned S3 URL
    # For simplicity, we'll just return a signed token that can be used to access the report
    
    # Ensure we have a report_id
    report_id ||= SecureRandom.uuid
    
    # Get a safe secret key - use a consistent approach to match the verification
    if Rails.env.production?
      # In production, we should always use a secure credential
      secret_key = Rails.application.credentials.secret_key_base || ENV['SECRET_KEY_BASE']
    else
      # In development/test, use a stable key for testing
      # THIS IS NOT SECURE FOR PRODUCTION - USE ONLY IN DEV/TEST
      secret_key = "development_key_for_compliance_reports"
    end
    
    # Generate an expiration timestamp
    expires_at = Time.current.to_i + expires_in.to_i
    
    # Create a simple signature
    account_id = account&.id || 0
    user_id = user&.id || 0
    data_to_sign = "#{report_id}:#{account_id}:#{user_id}:#{expires_at}"
    signature = OpenSSL::HMAC.hexdigest('sha256', secret_key, data_to_sign)
    
    # Create a token with all the necessary data
    token_data = {
      r: report_id,
      a: account_id,
      u: user_id,
      e: expires_at,
      s: signature
    }
    
    # Base64 encode the token data for URL safety
    token = Base64.urlsafe_encode64(token_data.to_json)
    
    # In production, this would be a real URL
    "/api/v1/compliance/reports/#{report_id}?token=#{token}"
  end

  private

  # Sign a report with HMAC to verify its integrity
  def sign_report(report_data)
    # Get a safe secret key - use a consistent approach to match the verification
    if Rails.env.production?
      # In production, we should always use a secure credential
      secret_key = Rails.application.credentials.secret_key_base || ENV['SECRET_KEY_BASE']
    else
      # In development/test, use a stable key for testing
      # THIS IS NOT SECURE FOR PRODUCTION - USE ONLY IN DEV/TEST
      secret_key = "development_key_for_compliance_reports"
    end
                 
    # Convert the report to a canonical JSON string
    json_data = report_data.to_json
    
    # Create an HMAC signature
    hmac = OpenSSL::HMAC.hexdigest('sha256', secret_key, json_data)
    
    # Add the signature to the report and return the result
    report_data.merge(
      signature: hmac,
      signature_algorithm: 'HMAC-SHA256',
      signed_at: Time.current.iso8601
    )
  end
end