# app/services/lead_submission_service.rb
class LeadSubmissionService
  def initialize(source, campaign, params)
    @source = source
    @campaign = campaign
    @params = params || {}
    @lead = nil
    @validation_errors = {}
    @processed_data = {}
    @api_request_id = nil
    
    # Stringify keys for consistency
    @params = stringify_keys(@params)
    
    # Log the parameters for debugging
    Rails.logger.debug "Lead submission service initialized with params: #{@params.inspect}"
    
    # Extract source token if present and set it in the headers for API authentication
    if @params['source_token'].present?
      @source_token = @params['source_token']
      # We don't want to pass this to the API as a param, only in the header
      @params.delete('source_token')
    end
    
    # Extract API request ID if present
    @api_request_id = @params['api_request_id']
  end
  
  # Helper method to stringify keys in a hash
  def stringify_keys(hash)
    return {} unless hash.is_a?(Hash)
    
    hash.each_with_object({}) do |(key, value), result|
      result[key.to_s] = value
    end
  end
  
  def process!
    # Create the lead record with basic information
    create_lead
    
    # Return early if lead creation failed
    if @lead.nil?
      Rails.logger.error("Lead creation failed: #{@lead&.errors&.full_messages}")
      
      # Check if we have validation errors
      if @validation_errors&.any?
        errors = @validation_errors.map { |field, failure| "#{failure[:message]}" }
        
        # Print debug info to help debug
        Rails.logger.debug "Form submission validation errors: #{@validation_errors.inspect}"
        Rails.logger.debug "Checking required fields, params: #{@params.keys}"
        
        return { 
          success: false, 
          message: 'Required fields missing', 
          errors: errors,
          validation_errors: @validation_errors
        }
      end
      
      # Otherwise generic error
      return { 
        success: false, 
        message: 'Failed to create lead', 
        errors: @lead&.errors&.full_messages || ['Unknown error creating lead'],
        validation_errors: {}
      }
    end
    
    # Parse and store the lead data fields
    store_lead_data
    
    # Process the lead data (normalize, calculate fields, enrich)
    process_lead_data
    
    # Validate the lead against campaign rules
    @validation_errors = @lead.validate_against_rules
    
    # Record validation activity
    if @validation_errors.empty?
      LeadActivityService.record_validation(@lead, {
        valid: true,
        validation_type: "campaign_rules",
        validations_passed: @lead.validation_rule_results&.select { |r| r[:passed] }&.count || 0
      })
    else
      LeadActivityService.record_validation(@lead, {
        valid: false,
        validation_type: "campaign_rules",
        validations_failed: @validation_errors.size,
        errors: @validation_errors.map { |rule_id, failure| "#{failure[:rule_name]}: #{failure[:message]}" }
      })
    end
    
    # Decide next steps based on validation and campaign configuration
    if @validation_errors.empty? || @lead.valid_for_distribution?
      # Lead is valid, proceed with bidding or direct distribution
      process_valid_lead
    else
      # Lead failed validation
      handle_invalid_lead
    end
  end
  
  private
  
  def create_lead
    # Pre-validations - check if required fields are present before creating the lead
    # This allows us to capture basic validation errors early
    validation_failures = {}
    
    # Debug for tracking
    field_check_results = []
    
    # Log the entire params hash for debugging
    Rails.logger.debug "Full params hash for lead creation: #{@params.inspect}"
    Rails.logger.debug "Params keys: #{@params.keys.inspect}"
    Rails.logger.debug "Params class: #{@params.class}"
    
    # The params should already have string keys from initialize,
    # but for safety we'll use them directly without normalization
    normalized_params = @params
    
    @campaign.campaign_fields.where(required: true).each do |field|
      # Get field value using the right strategy
      # For API submissions, we look directly for the field name
      field_value = normalized_params[field.name]
      
      # Log what was found
      Rails.logger.debug "Checking required field #{field.name} (#{field.label}): #{field_value.inspect}"
      
      has_value = field_value.present?
      
      # Add to debug log
      field_check_results << {
        field_name: field.name,
        field_label: field.label,
        value_received: field_value,
        has_value: has_value,
        param_keys: normalized_params.keys
      }
      
      # Skip if the field has a valid value
      next if has_value
      
      # Field is required but missing
      field_label = field.label.presence || field.name.to_s.humanize
      validation_failures[field.name] = {
        rule_name: "Required Field: #{field_label}",
        message: "#{field_label} is required",
        severity: "error"
      }
    end
    
    # Debug log the field checking results
    Rails.logger.debug "Field validation check: #{field_check_results.inspect}"
    
    # If basic validations fail, don't create the lead
    if validation_failures.any?
      errors = validation_failures.map { |field, failure| "#{failure[:rule_name]}: #{failure[:message]}" }
      @validation_errors = validation_failures
      return false
    end
    
    # Extract client information
    ip_address = @params['ip_address'] || Current.ip_address
    user_agent = @params['user_agent'] || Current.user_agent
    referrer = @params['referrer']
    
    # Create the lead with client information
    @lead = @source.leads.new(
      campaign: @campaign,
      status: :new_lead,
      account: @source.account,
      ip_address: ip_address,
      user_agent: user_agent,
      referrer: referrer
    )
    
    # Return false if save fails
    return false unless @lead.save
    
    # Set the Current context for consistent logging
    Current.ip_address = ip_address if ip_address.present?
    Current.user_agent = user_agent if user_agent.present?
    
    # Record lead submission using the class method
    LeadActivityService.record_submission(@lead, {
      source_id: @source.id,
      source_name: @source.name,
      campaign_id: @campaign.id,
      campaign_name: @campaign.name,
      source_ip: Current.ip_address,
      source_user_agent: Current.user_agent
    })
    
    # Associate API request if ID was provided
    if @api_request_id.present?
      api_request = ApiRequest.find_by(id: @api_request_id)
      if api_request
        api_request.update(lead: @lead)
        # Log the association for debugging
        Rails.logger.info("Associated API Request ##{@api_request_id} with Lead ##{@lead.id}")
      end
    end
    
    # Return the lead
    @lead
  end
  
  def store_lead_data
    initial_data = {}
    
    # Handle first_name and last_name explicitly since they're commonly required
    # and causing issues
    first_name_field = @campaign.campaign_fields.find_by(name: 'first_name')
    if first_name_field
      first_name = @params['first_name']
      if first_name.present?
        Rails.logger.info "Found first_name in params: #{first_name}"
        
        initial_data['first_name'] = first_name
        @lead.lead_data.create!(
          campaign_field: first_name_field,
          value: first_name
        )
      end
    end
    
    last_name_field = @campaign.campaign_fields.find_by(name: 'last_name')
    if last_name_field
      last_name = @params['last_name']
      if last_name.present?
        Rails.logger.info "Found last_name in params: #{last_name}"
        
        initial_data['last_name'] = last_name
        @lead.lead_data.create!(
          campaign_field: last_name_field,
          value: last_name
        )
      end
    end
    
    # Process each campaign field
    @campaign.campaign_fields.each do |field|
      # Skip if we already processed first_name or last_name
      next if field.name == 'first_name' && initial_data['first_name'].present?
      next if field.name == 'last_name' && initial_data['last_name'].present?
      
      # Get the value from params using various possible naming conventions
      field_value = @params[field.name] || 
                   @params[field.name.to_sym] ||
                   @params[field.name.underscore] || 
                   @params[field.name.underscore.to_sym] ||
                   @params[field.name.parameterize(separator: '_')] ||
                   @params[field.name.parameterize(separator: '_').to_sym]
      
      # Log for debugging
      Rails.logger.debug "Field mapping: #{field.name} = #{field_value.inspect}, required: #{field.required?}"
      
      # Skip if no value provided and field is not required
      next if field_value.blank? && !field.required?
      
      # Store in our temporary hash for processing
      initial_data[field.name] = field_value
      
      # Store the value in the lead_data
      @lead.lead_data.create!(
        campaign_field: field,
        value: field_value
      )
    end
    
    # Log the final data stored
    Rails.logger.info "Lead data stored: #{initial_data.inspect}"
    
    # Store the initial data for processing
    @processed_data = initial_data
  end
  
  def process_lead_data
    # Create a data processor for the lead
    processor = LeadDataProcessor.new(@lead, @processed_data)
    
    # Process the data (normalize, calculate fields, enrich)
    @processed_data = processor.process!
    
    # Save the processed data back to the lead
    processor.save_processed_data!(@processed_data)
    
    # Log that data processing is complete
    Rails.logger.info("Processed lead data for Lead ##{@lead.id}: normalized and enriched #{@processed_data.keys.count} fields")
  end
  
  def process_valid_lead
    # Update lead status to processing
    old_status = @lead.status
    @lead.update(status: :processing)
    
    # Record status update activity
    LeadActivityService.record_status_update(@lead, old_status, "processing", {
      reason: "Lead passed validation",
      next_step: @campaign.use_bidding_system? ? "bidding" : "direct_distribution"
    })
    
    if @campaign.use_bidding_system?
      # Process through bidding system
      process_through_bidding
    else
      # Direct distribution to endpoints
      process_through_direct_distribution
    end
  end
  
  def process_through_bidding
    # Record anonymization activity before bidding
    LeadActivityService.record_anonymization(@lead, {
      anonymization_type: "bidding_preparation",
      fields_anonymized: @lead.pii_field_names,
      anonymization_method: "hash"
    })
    
    # Create a bid service
    bid_service = BidService.new(@lead, @campaign)
    
    # Create a bid request and solicit bids
    bid_request = bid_service.solicit_bids!
    
    # Record bid request activity
    LeadActivityService.record_bid_request(@lead, bid_request, {
      ping_fields: bid_request.anonymized_data.keys,
      timeout_seconds: @campaign.bid_timeout_seconds,
      expiration_time: bid_request.expires_at
    })
    
    # Bidding is now in progress, this will be async
    # Return success with the bid request
    { 
      success: true, 
      lead: @lead, 
      bid_request: bid_request,
      message: 'Lead submitted successfully and bid request created' 
    }
  end
  
  def process_through_direct_distribution
    # Update lead status to processing
    @lead.update(status: :processing)
    
    # Use MultiDistributionService to handle all distribution strategies
    distribution_service = MultiDistributionService.new(@lead)
    
    # Distribute the lead according to campaign strategy
    result = distribution_service.distribute!
    
    if result[:success]
      # Status is already updated in MultiDistributionService
      success_message = "Lead submitted and distributed successfully"
      
      if result[:strategy] == 'parallel' && result[:success_count] > 0
        success_rate = "#{result[:success_count]}/#{result[:total_count]}"
        success_message += " (#{success_rate} distributions succeeded)"
      end
      
      { 
        success: true, 
        lead: @lead, 
        message: success_message,
        distribution_results: result
      }
    else
      # Status is already updated in MultiDistributionService
      error_message = result[:message] || 
                     'Failed to distribute lead'
      
      if result[:failed].present?
        error_details = result[:failed].map { |f| f[:error] }.compact.join("; ")
        error_message += ": #{error_details}" if error_details.present?
      end
      
      { 
        success: false, 
        lead: @lead, 
        message: error_message,
        distribution_results: result
      }
    end
  end
  
  def handle_invalid_lead
    # Format validation errors
    errors = @validation_errors.map do |rule_id, failure|
      "#{failure[:rule_name]}: #{failure[:message]}"
    end
    
    # Get detailed validation error info
    detailed_errors = @validation_errors.transform_values do |failure|
      {
        rule_name: failure[:rule_name],
        message: failure[:message],
        rule_id: failure[:rule_id],
        field: failure[:field]
      }
    end
    
    # Update lead status to rejected
    old_status = @lead.status
    @lead.update(status: :rejected)
    
    # Record status update activity
    LeadActivityService.record_status_update(@lead, old_status, "rejected", {
      reason: "Failed validation",
      validation_errors: errors
    })
    
    # Log validation failures
    Rails.logger.info("Lead ##{@lead.id} failed validation with #{errors.size} errors")
    Rails.logger.debug("Validation errors: #{detailed_errors.to_json}")
    
    { 
      success: false, 
      lead: @lead, 
      message: 'Lead failed validation', 
      errors: errors,
      validation_errors: detailed_errors,
      validation_rule_results: @lead.validation_rule_results
    }
  end
end