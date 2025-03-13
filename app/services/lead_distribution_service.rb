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
      
      # Determine the request type based on the distribution endpoint type
      # For ping_post distributions in post mode, we use :post to use the post_endpoint_url
      # For all others, we use regular :post (default)
      request_type = (distribution.endpoint_type == "ping_post") ? :post : :post
      
      # Send the request
      response = send_request(distribution, formatted_payload, request_type)
      
      # Record the API request with the endpoint URL that was actually used
      endpoint_url = select_endpoint_url(distribution, request_type)
      api_request = record_api_request(distribution, formatted_payload, response, nil, endpoint_url)
      
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
          endpoint_url: endpoint_url,
          request_method: distribution.request_method,
          response_code: api_request.response_code,
          request_type: request_type.to_s
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
            response_code: api_request.response_code,
            endpoint_url: endpoint_url
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
            error: api_request.error || "HTTP Error: #{api_request.response_code}",
            endpoint_url: endpoint_url
          }
        )
      end
    rescue => e
      # For error case, use the default endpoint URL
      endpoint_url = select_endpoint_url(distribution, :post)
      
      # Record the failed API request with the error
      api_request = record_api_request(distribution, payload, nil, e.message, endpoint_url)
      
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
          error_class: e.class.name,
          endpoint_url: endpoint_url
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

  def send_request(distribution, payload, request_type = :post)
    start_time = Time.now
    
    # Select appropriate endpoint URL based on request type and distribution endpoint type
    endpoint_url = select_endpoint_url(distribution, request_type)
    
    uri = URI.parse(endpoint_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 30 # 30 seconds timeout
    
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
    
    # Apply authentication based on method
    apply_authentication(request, distribution)
    
    # Add headers
    distribution.headers.each do |header|
      request[header.name] = header.value
    end
    
    # Send the request
    response = http.request(request)
    
    # Handle OAuth token refresh if needed
    if response.code.to_i == 401 && distribution.authentication_method == "oauth2"
      if refresh_oauth_token(distribution)
        # Try the request again with new token
        apply_authentication(request, distribution)
        response = http.request(request)
      end
    end
    
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
  
  # Select the appropriate endpoint URL based on the request type and distribution endpoint type
  def select_endpoint_url(distribution, request_type)
    case request_type
    when :ping
      # For ping, use bid_endpoint_url if available (for backwards compatibility)
      distribution.bid_endpoint_url.presence || distribution.endpoint_url
    when :post
      # For post, use post_endpoint_url if available (for ping_post type), otherwise regular endpoint_url
      if distribution.endpoint_type == "ping_post" && distribution.post_endpoint_url.present?
        distribution.post_endpoint_url
      else
        distribution.endpoint_url
      end
    else
      distribution.endpoint_url
    end
  end
  
  # Apply authentication to the request based on the distribution's authentication method
  def apply_authentication(request, distribution)
    if distribution.authentication_method_token?
      # Add API key to header or query param based on location
      if distribution.api_key_location == "header"
        request[distribution.api_key_name] = distribution.authentication_token
      else
        # Add to query params for GET or to body for others
        # Implementation depends on your payload structure
      end
    elsif distribution.authentication_method_basic_auth?
      # Use HTTP Basic Auth
      request.basic_auth(distribution.username, distribution.password)
    elsif distribution.authentication_method_oauth2?
      # Get or refresh OAuth token
      token = get_oauth_token(distribution)
      request["Authorization"] = "Bearer #{token}" if token.present?
    elsif distribution.authentication_method_jwt?
      # Generate JWT
      token = generate_jwt(distribution)
      request["Authorization"] = "Bearer #{token}" if token.present?
    end
  end
  
  # Get OAuth token, refreshing if necessary
  def get_oauth_token(distribution)
    # Check if token exists and is still valid
    if distribution.access_token.present? && distribution.token_expires_at.present?
      # If token expires in the next 5 minutes, refresh it
      if distribution.token_expires_at > Time.current + 5.minutes
        return distribution.access_token
      end
    end
    
    # Token doesn't exist or is expiring soon, refresh it
    refresh_oauth_token(distribution)
    distribution.access_token
  end
  
  # Refresh OAuth token
  def refresh_oauth_token(distribution)
    return false unless distribution.client_id.present? && distribution.client_secret.present? && distribution.token_url.present?
    
    begin
      uri = URI.parse(distribution.token_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      
      request = Net::HTTP::Post.new(uri)
      request.content_type = 'application/x-www-form-urlencoded'
      
      # Construct appropriate OAuth payload based on whether we're doing initial token or refresh
      if distribution.refresh_token.present?
        # Use refresh token flow
        request.set_form_data({
          'grant_type' => 'refresh_token',
          'refresh_token' => distribution.refresh_token,
          'client_id' => distribution.client_id,
          'client_secret' => distribution.client_secret
        })
      else
        # Use client credentials flow
        request.set_form_data({
          'grant_type' => 'client_credentials',
          'client_id' => distribution.client_id,
          'client_secret' => distribution.client_secret
        })
      end
      
      response = http.request(request)
      
      if response.code.to_i == 200
        # Parse response to get token
        token_data = JSON.parse(response.body)
        
        # Update distribution with new token info
        distribution.update(
          access_token: token_data['access_token'],
          refresh_token: token_data['refresh_token'] || distribution.refresh_token,
          token_expires_at: Time.current + token_data['expires_in'].to_i.seconds
        )
        
        return true
      else
        Rails.logger.error("OAuth token refresh failed: #{response.body}")
        return false
      end
    rescue => e
      Rails.logger.error("OAuth token refresh error: #{e.message}")
      return false
    end
  end
  
  # Generate a JWT token
  def generate_jwt(distribution)
    # JWT implementation would go here
    # This is a placeholder - in a real application, you would implement JWT generation
    # based on your specific requirements
    
    # Example:
    # payload = {
    #   iss: distribution.client_id,
    #   exp: Time.now.to_i + 3600,
    #   iat: Time.now.to_i
    # }
    # JWT.encode(payload, distribution.client_secret, 'HS256')
    
    # For now, return nil
    nil
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

  def record_api_request(distribution, payload, response, error = nil, endpoint_url = nil)
    api_request = distribution.api_requests.new(
      requestable: distribution,
      lead: @lead,
      endpoint_url: endpoint_url || distribution.endpoint_url,
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