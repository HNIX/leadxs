class BidRequestJob < ApplicationJob
  queue_as :bids
  
  # Configure retry settings
  # Use a fixed delay instead of an array for compatibility
  retry_on StandardError, wait: 30.seconds, attempts: 3
  
  def perform(bid_request_id, distribution_id)
    # Find the bid request
    bid_request = BidRequest.find_by(id: bid_request_id)
    if bid_request.nil?
      Rails.logger.error("BidRequest ##{bid_request_id} not found")
      return
    end
    
    # Find the distribution
    distribution = Distribution.find_by(id: distribution_id)
    if distribution.nil?
      Rails.logger.error("Distribution ##{distribution_id} not found")
      return
    end
    
    # Verify bid request state
    # Skip if already expired or completed, but allow pending or active states
    if bid_request.status.in?(['expired', 'completed', 'canceled'])
      Rails.logger.info("Skipping bid request ##{bid_request_id} in #{bid_request.status} state")
      return
    end
    
    # If the bid request has technically expired but not marked as such,
    # mark it as expired but continue processing for reliability
    if bid_request.expires_at < Time.current && bid_request.status != 'expired'
      Rails.logger.info("Processing technically expired bid request ##{bid_request_id}")
      
      # Update status but don't save yet to avoid race conditions
      bid_request.status = 'expired' unless bid_request.status == 'completed'
    end
    
    Rails.logger.info("Processing bid request ##{bid_request_id} to distribution ##{distribution_id}")
    
    begin
      # Get the anonymized data
      lead_data = bid_request.field_values_hash
      
      # Send bid request to the distribution endpoint
      endpoint_url = distribution.bid_endpoint_url || distribution.endpoint_url
      Rails.logger.info("Sending request to endpoint: #{endpoint_url}")
      
      bid_response = send_bid_request(distribution, lead_data, bid_request)
      
      # Process the response
      process_bid_response(bid_request, distribution, bid_response)
      
      # Now save the status change if we marked it expired earlier
      bid_request.save if bid_request.changed?
      
    rescue => e
      Rails.logger.error("Error requesting bid: #{e.message}")
      
      # Record the failed API request
      api_request = record_api_request(
        distribution, 
        lead_data || {}, 
        { error: e.message },
        bid_request
      )
      
      # Re-raise for retry mechanism to handle
      raise
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
    
    # Include time remaining for bid calculations
    seconds_remaining = [0, (bid_request.expires_at - Time.current)].max.to_i
    payload[:seconds_remaining] = seconds_remaining
    
    # Format the payload according to distribution format
    formatted_payload = format_payload(distribution, payload)
    
    # Send the request
    endpoint_url = distribution.bid_endpoint_url || distribution.endpoint_url
    
    # In test/development environments, handle example.com specially
    if Rails.env.development? || Rails.env.test?
      if endpoint_url.include?('example.com')
        mock_amount = distribution.base_bid_amount || 5.0
        mock_body = { bid_amount: mock_amount }.to_json
        
        Rails.logger.info("Using mock response for #{endpoint_url} with bid_amount: #{mock_amount}, body: #{mock_body}")
        Rails.logger.info("MOCK DISTRIBUTION INFO: id=#{distribution.id}, name=#{distribution.name}, base_bid_amount=#{distribution.base_bid_amount}")
        
        # Return a mock response for development/testing
        return {
          code: 200,
          body: mock_body,
          duration_ms: 50,
          mock: true
        }
      end
    end
    
    uri = URI.parse(endpoint_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    # Configure timeouts based on time remaining in the bid request
    # Use a dynamic timeout to ensure we don't wait longer than the bid expires
    # with a minimum of 2 seconds and maximum of 30 seconds
    remaining_bid_time = [2, [30, seconds_remaining].min].max
    
    # Configure HTTP client timeouts - use shorter timeouts in development
    if Rails.env.development? || Rails.env.test?
      http.open_timeout = 2 # Very short timeout for development
      http.read_timeout = 3 # Very short timeout for development
    else
      http.open_timeout = [remaining_bid_time * 0.3, 5].min.to_i # 30% of remaining time or 5 seconds, whichever is less
      http.read_timeout = [remaining_bid_time * 0.7, 25].min.to_i # 70% of remaining time or 25 seconds, whichever is less 
    end
    
    http.ssl_timeout = http.open_timeout
    
    # Log the timeout settings
    Rails.logger.info("HTTP timeouts configured - open: #{http.open_timeout}s, read: #{http.read_timeout}s, remaining: #{seconds_remaining}s")
    
    # Create request object
    request = Net::HTTP::Post.new(uri)
    set_request_headers(request, distribution)
    set_request_payload(request, distribution, formatted_payload)
    
    # Send the request
    response = http.request(request)
    
    # Calculate duration
    duration_ms = ((Time.now - start_time) * 1000).to_i
    
    # Return a structured response
    {
      code: response.code.to_i,
      body: response.body,
      duration_ms: duration_ms,
      headers: response.to_hash
    }
  rescue Net::OpenTimeout => e
    Rails.logger.error("Connection timeout error with distribution #{distribution.id}: #{e.message}")
    {
      error: "Connection timeout: #{e.message}",
      error_type: "timeout",
      duration_ms: ((Time.now - start_time) * 1000).to_i
    }
  rescue Net::ReadTimeout => e
    Rails.logger.error("Read timeout error with distribution #{distribution.id}: #{e.message}")
    {
      error: "Read timeout: #{e.message}",
      error_type: "timeout",
      duration_ms: ((Time.now - start_time) * 1000).to_i
    }
  rescue => e
    Rails.logger.error("HTTP request error with distribution #{distribution.id}: #{e.message} (#{e.class.name})")
    {
      error: e.message,
      error_type: "error",
      error_class: e.class.name,
      duration_ms: ((Time.now - start_time) * 1000).to_i
    }
  end
  
  def process_bid_response(bid_request, distribution, response)
    # Check if response contains an error
    if response[:error].present?
      Rails.logger.info("Bid response contains error: #{response[:error]}")
      
      # Record the API request with error
      api_request = record_api_request(
        distribution,
        { bid_request_id: bid_request.unique_id },
        response,
        bid_request
      )
      
      # Use fallback bid amount if configured
      if distribution.bid_on_error && distribution.base_bid_amount.present? && distribution.base_bid_amount > 0
        Rails.logger.info("Using fallback bid amount due to error: #{distribution.base_bid_amount}")
        
        bid = Bid.create!(
          bid_request: bid_request,
          distribution: distribution,
          amount: distribution.base_bid_amount,
          status: :pending,
          is_fallback: true,
          account: bid_request.account,
          api_request: api_request
        )
        
        # Log the fallback bid received in the lead activity log
        if bid_request.lead.present?
          Rails.logger.info("Recording fallback bid received activity for lead ##{bid_request.lead.id}")
          LeadActivityService.record_bid_received(bid_request.lead, bid, { is_fallback: true })
        end
        
        return bid
      end
      
      return nil
    end
    
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
      Rails.logger.info("Creating bid with valid amount: #{bid_amount}")
      
      # Create the bid without the api_request
      bid = Bid.create!(
        bid_request: bid_request,
        distribution: distribution,
        amount: bid_amount,
        status: :pending,
        account: bid_request.account,
        is_fallback: response[:mock].present?
      )
      
      # Update the API request to associate it with the bid
      # Make sure we maintain the lead association
      if api_request.present?
        api_request.update!(requestable: bid)
        Rails.logger.info("Updated API request ##{api_request.id} requestable to bid ##{bid.id}")
      end
      
      # Log the bid received in the lead activity log
      if bid_request.lead.present?
        Rails.logger.info("Recording bid received activity for lead ##{bid_request.lead.id}")
        LeadActivityService.record_bid_received(bid_request.lead, bid)
      end
      
      return bid
    else
      Rails.logger.info("No valid bid amount extracted from response: #{bid_amount}, code: #{response[:code]}")
    end
    
    nil
  end
  
  def extract_bid_amount(response, distribution)
    # Handle errors
    return 0 if response[:error].present?
    
    # Handle special mock responses in development/test
    if response[:mock] && distribution.base_bid_amount.present?
      Rails.logger.info("Using mock bid amount: #{distribution.base_bid_amount}")
      return distribution.base_bid_amount
    end
    
    # Require successful HTTP status (2xx) for real responses
    return 0 unless (200..299).include?(response[:code])
    
    begin
      case distribution.request_format
      when "json"
        # Handle empty response
        return 0 if response[:body].blank?
        
        # Parse JSON
        data = JSON.parse(response[:body])
        
        # Look for bid amount in various possible fields
        amount = data["bid_amount"] || data["amount"] || data["bid"] || 
                 data["price"] || data["value"] || data["cost"] || 
                 data.dig("response", "bid_amount") || data.dig("data", "bid")
        
        # Convert to float or use base amount as fallback
        amount = amount.to_f if amount.present?
        amount = distribution.base_bid_amount if amount.blank? || amount == 0
        
        # Log the extracted amount
        Rails.logger.info("Extracted bid amount from JSON: #{amount}")
        
        amount || 0
      when "xml"
        # Basic XML parsing with enhanced path search
        doc = Nokogiri::XML(response[:body])
        paths = ["//bid_amount", "//amount", "//bid", "//price", 
                 "//value", "//cost", "//response/bid_amount", "//data/bid"]
        
        node = nil
        paths.each do |path|
          node = doc.at_xpath(path)
          break if node.present?
        end
        
        amount = node&.text&.to_f
        amount = distribution.base_bid_amount if amount.blank? || amount == 0
        
        # Log the extracted amount
        Rails.logger.info("Extracted bid amount from XML: #{amount}")
        
        amount || 0
      else
        # If unknown format but we have a base bid amount, use that
        if distribution.base_bid_amount.present? && distribution.base_bid_amount > 0
          distribution.base_bid_amount
        else
          0
        end
      end
    rescue => e
      Rails.logger.error("Error parsing bid amount: #{e.message}")
      
      # Use fallback in case of parsing error
      distribution.base_bid_amount.present? ? distribution.base_bid_amount : 0
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
    
    # Associate with lead if present in bid_request
    if bid_request.lead.present?
      api_request.lead = bid_request.lead
    end
    
    if response
      api_request.response_code = response[:code]
      api_request.response_payload = response[:body]
      api_request.duration_ms = response[:duration_ms]
      api_request.error = response[:error]
    end
    
    api_request.mark_as_sent if api_request.respond_to?(:mark_as_sent)
    api_request.save!
    
    # Log API request creation
    Rails.logger.info("Created API request ##{api_request.id} for distribution ##{distribution.id}, associated with #{bid_request.lead.present? ? "lead ##{bid_request.lead.id}" : "no lead"}")
    
    api_request
  end
end