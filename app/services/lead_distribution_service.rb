# app/services/lead_distribution_service.rb
class LeadDistributionService
  require 'net/http'
  require 'uri'
  require 'json'

  def initialize(lead)
    @lead = lead
    @campaign = lead.campaign
    @successful_distributions = []
    @failed_distributions = []
    @compliance_service = ComplianceService.new(account: @lead.account)
    @lead_activity_service = LeadActivityService.new
  end

  # Distribute lead to all active distributions for the campaign
  def distribute!
    # Get active distributions for this campaign
    distributions = active_distributions

    return { success: false, message: "No active distributions found" } if distributions.empty?

    # Process each distribution
    distributions.each do |campaign_distribution|
      process_distribution(campaign_distribution)
    end

    {
      success: @failed_distributions.empty?,
      successful: @successful_distributions,
      failed: @failed_distributions
    }
  end

  # Distribute lead to specific distribution (used after bidding)
  def distribute_to_specific!(campaign_distribution)
    return { success: false, message: "Invalid distribution" } unless campaign_distribution

    process_distribution(campaign_distribution)

    if @failed_distributions.empty?
      { success: true, distribution: campaign_distribution.distribution }
    else
      {
        success: false,
        distribution: campaign_distribution.distribution,
        error: @failed_distributions.first[:error]
      }
    end
  end

  # Select a winner based on campaign's distribution method
  def select_winner(distributions_data)
    return nil if distributions_data.empty?
    
    case @campaign.distribution_method
    when 'highest_bid'
      # Sort by bid amount descending and return the first
      distributions_data.sort_by { |d| -d[:bid].to_f }.first
    when 'weighted_random'
      # Implement weighted random selection based on bid amounts
      total_amount = distributions_data.sum { |d| d[:bid].to_f }
      return distributions_data.first if total_amount <= 0
      
      random_point = rand * total_amount
      current_sum = 0
      
      distributions_data.each do |distribution_data|
        current_sum += distribution_data[:bid].to_f
        return distribution_data if current_sum >= random_point
      end
      
      distributions_data.first # Fallback
    when 'round_robin'
      # Get the distribution that was least recently used
      campaign_distributions = @campaign.campaign_distributions.where(distribution_id: distributions_data.map { |d| d[:distribution].id })
      campaign_distributions.order(last_used_at: :asc).first&.distribution
      
      # If we found a match, return the distribution data for it
      selected_distribution = campaign_distributions.order(last_used_at: :asc).first&.distribution
      distributions_data.find { |d| d[:distribution] == selected_distribution } || distributions_data.first
    when 'waterfall'
      # Sort by priority ascending and return the first
      distributions_data.sort_by { |d| d[:priority] || 999 }.first
    else
      # Default to highest priority
      distributions_data.sort_by { |d| d[:priority] || 999 }.first
    end
  end

  private

  def active_distributions
    @campaign.campaign_distributions
             .joins(:distribution)
             .where(active: true)
             .where(distributions: { status: :active })
             .order(priority: :asc)
  end

  def process_distribution(campaign_distribution)
    distribution = campaign_distribution.distribution
    
    # Skip if not all required fields are mapped
    unless campaign_distribution.all_required_fields_mapped?
      @failed_distributions << {
        distribution: distribution,
        error: "Not all required fields are mapped"
      }
      return
    end
    
    # Verify proper consent has been collected for this distribution
    unless lead_has_consent_for_distribution?(distribution)
      # Record consent requested activity if consent is required
      if distribution_requires_consent?(distribution)
        @lead_activity_service.record_consent_requested(@lead, distribution, {
          consent_type: "distribution_consent",
          buyer_name: distribution.name,
          buyer_type: distribution.integration_type
        })
      end
      
      @failed_distributions << {
        distribution: distribution,
        error: "Missing required consent for this distribution"
      }
      
      # Log consent failure to compliance records
      @compliance_service.record_distribution(
        @lead, 
        distribution, 
        ComplianceRecord::DISTRIBUTION_FAILED, 
        { reason: "Missing required consent" }
      )
      
      return
    end
    
    # If we have consent, record that it was provided
    if distribution_requires_consent?(distribution)
      # Find the active consent record
      consent_record = @lead.active_consent_records.find_by(consent_type: ConsentRecord::DISTRIBUTION_CONSENT)
      
      if consent_record
        @lead_activity_service.record_consent_provided(@lead, consent_record, {
          buyer_name: distribution.name,
          buyer_type: distribution.integration_type,
          consent_timestamp: consent_record.created_at
        })
      end
    end
    
    # Log distribution attempt to compliance
    @compliance_service.record_distribution(
      @lead, 
      distribution, 
      ComplianceRecord::DISTRIBUTION_ATTEMPTED,
      { campaign_distribution_id: campaign_distribution.id }
    )
    
    begin
      # Use FieldMapper to prepare the payload
      field_mapper = FieldMapper.new(@lead, campaign_distribution)
      payload = field_mapper.build_payload
      
      # Format the payload according to distribution requirements
      formatted_payload = format_payload(distribution, payload)
      
      # Send the request
      response = send_request(distribution, formatted_payload)
      
      # Record the API request
      api_request = record_api_request(distribution, formatted_payload, response)
      
      # Update last_used_at timestamp for round robin distribution
      update_last_used_timestamp(campaign_distribution) if api_request.successful?
      
      if api_request.successful?
        @successful_distributions << {
          distribution: distribution,
          api_request: api_request
        }
        
        # Log successful distribution to activity timeline
        @lead_activity_service.record_distribution(@lead, api_request, {
          distribution_id: distribution.id,
          distribution_name: distribution.name,
          distribution_type: distribution.integration_type,
          endpoint_url: distribution.endpoint_url,
          request_method: distribution.request_method,
          response_code: api_request.response_code
        })
        
        # Log buyer response
        response_status = determine_response_status(api_request)
        @lead_activity_service.record_buyer_response(@lead, api_request, {
          distribution_id: distribution.id,
          distribution_name: distribution.name,
          response_status: response_status,
          response_time: api_request.duration_ms / 1000.0,
          response_data: parse_response_data(api_request)
        })
        
        # Log successful distribution to compliance records
        @compliance_service.record_distribution(
          @lead, 
          distribution, 
          ComplianceRecord::DISTRIBUTION_SUCCEEDED, 
          { 
            api_request_id: api_request.id,
            response_code: api_request.response_code
          }
        )
      else
        @failed_distributions << {
          distribution: distribution,
          api_request: api_request,
          error: api_request.error || "HTTP Error: #{api_request.response_code}"
        }
        
        # Log failed distribution to compliance records
        @compliance_service.record_distribution(
          @lead, 
          distribution, 
          ComplianceRecord::DISTRIBUTION_FAILED, 
          { 
            api_request_id: api_request.id,
            response_code: api_request.response_code,
            error: api_request.error || "HTTP Error: #{api_request.response_code}"
          }
        )
      end
    rescue => e
      # Record the failed API request with the error
      api_request = record_api_request(distribution, payload, nil, e.message)
      
      @failed_distributions << {
        distribution: distribution,
        api_request: api_request,
        error: e.message
      }
      
      # Log exception to compliance records
      @compliance_service.record_distribution(
        @lead, 
        distribution, 
        ComplianceRecord::DISTRIBUTION_FAILED, 
        { 
          api_request_id: api_request.id,
          error: e.message,
          error_class: e.class.name
        }
      )
    end
  end

  def format_payload(distribution, data)
    case distribution.request_format
    when "json"
      data.to_json
    when "xml"
      # Basic XML conversion - in production you might want a more robust XML builder
      xml_content = data.map { |k, v| "<#{k}>#{v}</#{k}>" }.join
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?><lead>#{xml_content}</lead>"
    when "form"
      data # Keep as hash for form submission
    else
      data.to_json # Default to JSON
    end
  end

  def send_request(distribution, payload)
    start_time = Time.now
    
    uri = URI.parse(distribution.endpoint_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    # Create the appropriate request object based on method
    request = case distribution.request_method
              when "get"
                uri.query = URI.encode_www_form(payload) if payload.is_a?(Hash)
                Net::HTTP::Get.new(uri)
              when "post"
                req = Net::HTTP::Post.new(uri)
                set_request_payload(req, distribution, payload)
                req
              when "put"
                req = Net::HTTP::Put.new(uri)
                set_request_payload(req, distribution, payload)
                req
              when "patch"
                req = Net::HTTP::Patch.new(uri)
                set_request_payload(req, distribution, payload)
                req
              end
    
    # Add headers
    distribution.headers.each do |header|
      request[header.name] = header.value
    end
    
    # Send the request
    response = http.request(request)
    
    # Calculate duration
    duration_ms = ((Time.now - start_time) * 1000).to_i
    
    {
      code: response.code.to_i,
      body: response.body,
      duration_ms: duration_ms
    }
  rescue => e
    {
      error: e.message,
      duration_ms: ((Time.now - start_time) * 1000).to_i
    }
  end

  def set_request_payload(request, distribution, payload)
    case distribution.request_format
    when "json"
      request.content_type = 'application/json'
      request.body = payload
    when "xml"
      request.content_type = 'application/xml'
      request.body = payload
    when "form"
      request.content_type = 'application/x-www-form-urlencoded'
      request.set_form_data(payload)
    end
  end

  def record_api_request(distribution, payload, response, error = nil)
    api_request = distribution.api_requests.new(
      requestable: distribution,
      lead: @lead,
      endpoint_url: distribution.endpoint_url,
      request_method: distribution.request_method.to_sym,
      request_payload: payload
    )
    
    if response
      api_request.response_code = response[:code]
      api_request.response_data = response[:body]
      api_request.duration_ms = response[:duration_ms]
    end
    
    api_request.error = error || response&.dig(:error)
    api_request.mark_as_sent
    api_request.save!
    
    api_request
  end
  
  def update_last_used_timestamp(campaign_distribution)
    campaign_distribution.update(last_used_at: Time.current)
  end
  
  # Check if lead has proper consent for distribution
  def lead_has_consent_for_distribution?(distribution)
    # If distribution doesn't require explicit consent, return true
    return true unless distribution_requires_consent?(distribution)
    
    # Check if lead has active consent record of type DISTRIBUTION_CONSENT
    @lead.has_consent?(ConsentRecord::DISTRIBUTION_CONSENT)
  end
  
  # Determine if distribution requires explicit consent
  def distribution_requires_consent?(distribution)
    # This logic would be based on your business rules
    # For example, you might require consent for certain high-risk verticals
    # or for distributions to certain companies
    
    # For now, as a placeholder, we'll assume all distributions require consent
    # In a real implementation, you would have more complex logic
    true
  end
  
  # Determine the response status based on the API request
  def determine_response_status(api_request)
    return "error" if api_request.error.present?
    
    case api_request.response_code
    when 200..299
      "accepted" 
    when 400..499
      "rejected"
    when 500..599
      "error"
    else
      "unknown"
    end
  end
  
  # Parse the response data from the API request
  def parse_response_data(api_request)
    return {} if api_request.response_data.blank?
    
    begin
      # Try to parse as JSON
      JSON.parse(api_request.response_data)
    rescue JSON::ParserError
      # If not JSON, return as plain text
      { message: api_request.response_data.to_s.truncate(500) }
    end
  end
end