class BidRequestJob < ApplicationJob
  queue_as :bids
  
  def perform(bid_request_id, distribution_id)
    bid_request = BidRequest.find_by(id: bid_request_id)
    distribution = Distribution.find_by(id: distribution_id)
    
    return if bid_request.nil? || distribution.nil?
    return if bid_request.expired?
    
    begin
      # Get the anonymized data
      lead_data = bid_request.field_values_hash
      
      # Send bid request to the distribution endpoint
      bid_response = send_bid_request(distribution, lead_data, bid_request)
      
      # Process the response
      process_bid_response(bid_request, distribution, bid_response)
    rescue => e
      Rails.logger.error("Error requesting bid from #{distribution.name}: #{e.message}")
      
      # Record the failed API request
      api_request = record_api_request(
        distribution, 
        lead_data, 
        { error: e.message },
        bid_request
      )
    end
  end
  
  private
  
  def send_bid_request(distribution, lead_data, bid_request)
    start_time = Time.now
    
    # Prepare the payload
    payload = {
      bid_request_id: bid_request.unique_id,
      campaign_id: bid_request.campaign_id,
      anonymized_data: lead_data,
      expires_at: bid_request.expires_at.iso8601
    }
    
    # Format the payload according to distribution format
    formatted_payload = format_payload(distribution, payload)
    
    # Send the request
    uri = URI.parse(distribution.bid_endpoint_url || distribution.endpoint_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = [distribution.bidding_timeout_seconds, 10].min # Use lower of distribution timeout or 10 seconds
    
    # Create request object
    request = Net::HTTP::Post.new(uri)
    set_request_headers(request, distribution)
    set_request_payload(request, distribution, formatted_payload)
    
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
  
  def process_bid_response(bid_request, distribution, response)
    # Parse the bid amount from the response
    bid_amount = extract_bid_amount(response, distribution)
    
    # Record the API request
    api_request = record_api_request(
      distribution,
      { bid_request_id: bid_request.unique_id },
      response,
      bid_request
    )
    
    # Create a bid if amount is valid
    if bid_amount && bid_amount > 0
      bid = Bid.create!(
        bid_request: bid_request,
        distribution: distribution,
        amount: bid_amount,
        status: :pending,
        account: bid_request.account,
        api_request: api_request
      )
      
      return bid
    end
    
    nil
  end
  
  def extract_bid_amount(response, distribution)
    return 0 if response[:error].present?
    return 0 unless (200..299).include?(response[:code])
    
    begin
      case distribution.request_format
      when "json"
        data = JSON.parse(response[:body])
        data["bid_amount"] || data["amount"] || data["bid"] || 0
      when "xml"
        # Basic XML parsing
        doc = Nokogiri::XML(response[:body])
        node = doc.at_xpath("//bid_amount") || doc.at_xpath("//amount") || doc.at_xpath("//bid")
        node&.text&.to_f || 0
      else
        # Default fallback
        0
      end
    rescue => e
      Rails.logger.error("Error parsing bid amount: #{e.message}")
      0
    end
  end
  
  def set_request_headers(request, distribution)
    # Add standard headers
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    
    # Add custom headers from distribution
    distribution.headers&.each do |header|
      request[header.name] = header.value
    end
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
  
  def format_payload(distribution, data)
    case distribution.request_format
    when "json"
      data.to_json
    when "xml"
      # Basic XML conversion
      xml_content = data.map do |k, v|
        if v.is_a?(Hash)
          nested = v.map { |nk, nv| "<#{nk}>#{nv}</#{nk}>" }.join
          "<#{k}>#{nested}</#{k}>"
        else
          "<#{k}>#{v}</#{k}>"
        end
      end.join
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?><bid_request>#{xml_content}</bid_request>"
    when "form"
      data # Keep as hash for form submission
    else
      data.to_json # Default to JSON
    end
  end
  
  def record_api_request(distribution, payload, response, bid_request)
    api_request = ApiRequest.new(
      requestable: distribution,
      uuid: SecureRandom.uuid,
      endpoint_url: distribution.bid_endpoint_url || distribution.endpoint_url,
      request_method: :post,
      request_payload: payload,
      account: bid_request.account
    )
    
    if response
      api_request.response_code = response[:code]
      api_request.response_payload = response[:body]
      api_request.duration_ms = response[:duration_ms]
      api_request.error = response[:error]
    end
    
    api_request.mark_as_sent if api_request.respond_to?(:mark_as_sent)
    api_request.save!
    
    api_request
  end
end