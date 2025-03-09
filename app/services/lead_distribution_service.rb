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
  end

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
    
    begin
      # Build payload for this distribution
      payload = build_payload(campaign_distribution)
      
      # Send the request
      response = send_request(distribution, payload)
      
      # Record the API request
      api_request = record_api_request(distribution, payload, response)
      
      if api_request.successful?
        @successful_distributions << {
          distribution: distribution,
          api_request: api_request
        }
      else
        @failed_distributions << {
          distribution: distribution,
          api_request: api_request,
          error: api_request.error || "HTTP Error: #{api_request.response_code}"
        }
      end
    rescue => e
      # Record the failed API request with the error
      api_request = record_api_request(distribution, payload, nil, e.message)
      
      @failed_distributions << {
        distribution: distribution,
        api_request: api_request,
        error: e.message
      }
    end
  end

  def build_payload(campaign_distribution)
    payload = {}
    
    # Process each mapped field
    campaign_distribution.mapped_fields.each do |mapped_field|
      field_name = mapped_field.distribution_field_name
      field_value = mapped_field.value_for_lead(@lead)
      
      # Skip nil values unless required
      next if field_value.nil? && !mapped_field.required?
      
      # Add to payload
      payload[field_name] = field_value
    end
    
    # Format payload according to distribution format
    format_payload(campaign_distribution.distribution, payload)
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
end