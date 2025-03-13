class FormSubmission < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :form_builder
  belongs_to :lead, optional: true
  
  STATUSES = %w[submitted processing completed rejected error].freeze
  
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :form_data, presence: true
  
  # Add the account association via the form builder for proper tenant scoping
  delegate :account, to: :form_builder
  
  # Process the form submission to create a lead
  def process!
    # Skip processing if already processed
    return if status != 'submitted'
    
    # Update status to processing
    update(status: 'processing')
    
    # Create a hash of field values for lead creation
    field_values = {}
    source = nil
    
    # Debug the form data for troubleshooting
    Rails.logger.debug "Form submission raw data: #{form_data.inspect}"
    
    begin
      # Get campaign from form builder
      campaign = form_builder.campaign
      
      # Get source and token from metadata
      source_id = metadata['source_id']
      source_token = metadata['source_token']
      
      Rails.logger.debug "Processing form submission for source ID: #{source_id}"
      
      # Try direct lookup first
      source = Source.find_by(id: source_id)
      
      # Return with error if no source found
      if source.nil?
        update(status: 'error', metadata: metadata.merge(error: "No source found for ID: #{source_id}"))
        return
      end
      
      # Verify the token matches
      if source.token != source_token
        update(status: 'error', metadata: metadata.merge(error: "Invalid source token"))
        return
      end
      
      # Verify the source is active
      unless source.active?
        update(status: 'error', metadata: metadata.merge(error: "Source is not active"))
        return
      end
      
      # The form data should already be mapped to campaign field names by the form_public_controller.js
      # But we'll add a fallback in case some values are still using element IDs
      
      # Direct check for first_name and last_name since these are commonly required
      # and causing validation issues
      if form_data['first_name'].present?
        field_values['first_name'] = form_data['first_name']
        Rails.logger.info "Adding first_name directly from form_data: #{form_data['first_name']}"
      end
      
      if form_data['last_name'].present?
        field_values['last_name'] = form_data['last_name']
        Rails.logger.info "Adding last_name directly from form_data: #{form_data['last_name']}"
      end
      
      # Process any already mapped field values (using actual field names)
      form_data.each do |key, value|
        # Skip empty values or already processed first/last name
        next if value.blank?
        next if key == 'first_name' && field_values['first_name'].present?
        next if key == 'last_name' && field_values['last_name'].present?
        
        # Check if this key matches a campaign field name directly
        if campaign.campaign_fields.exists?(name: key)
          field_values[key] = value
          Rails.logger.debug "Mapped field from name: #{key} = #{value}"
        end
      end
      
      # Then look for any element IDs that need mapping
      form_builder.elements.each do |element|
        next unless element.campaign_field_id.present?
        element_id = element.id.to_s
        
        # Skip if we don't have data for this element or if we already have this field
        next unless form_data[element_id].present?
        next if field_values[element.campaign_field.name].present?
        
        # Map the element ID to the field name
        field_values[element.campaign_field.name] = form_data[element_id]
        Rails.logger.debug "Mapped field from element: #{element_id} -> #{element.campaign_field.name} = #{form_data[element_id]}"
      end
      
      # Log the final field values after all mapping
      Rails.logger.info "Final field values for lead creation: #{field_values.inspect}"
      
      # Add consent information
      field_values['consent_text'] = consent_text if consent_text.present?
      
      # Create debug log
      debug_log = {
        timestamp: Time.current.to_s,
        event: 'processing_form_submission',
        source_id: source.id,
        form_submission_id: id,
        metadata: metadata,
        field_values: field_values
      }
      
      # Log for debugging
      Rails.logger.debug("Form submission debug log: #{debug_log.to_json}")
      
      # Add debug log to metadata
      update(metadata: metadata.merge(debug_log: debug_log))
      
      # Create API request context
      api_context = {
        ip_address: ip_address,
        user_agent: user_agent,
        source_id: source.id,
        form_submission_id: id,
        submission_type: 'form_builder'
      }
      
      # For form submissions, we use the source token from metadata
      api_token = source_token
      
      # Double check that we have a token
      if api_token.nil?
        update(status: 'error', metadata: metadata.merge(error: 'No API token found for source'))
        return
      end
      
      # Create API request - use the source as the requestable
      api_request = ApiRequest.create!(
        requestable: source,
        account: form_builder.account,
        endpoint_url: "/api/v1/lead_posts", # Use internal API endpoint
        request_method: :post,
        request_payload: field_values.to_json,
        request_headers: {
          'X-Source-Token' => api_token
        },
        response_code: 202, # Accepted - async processing
        response_payload: { message: "Processing form submission" }.to_json,
        duration_ms: 0,
        sent_at: Time.current
      )
      
      # Process lead submission - pass the field values directly as expected by the service
      # Merge the field values into the params hash directly
      submission_params = field_values.merge({
        # Add metadata for tracking
        api_request_id: api_request.id,
        form_submission_id: id,
        form_builder_id: form_builder.id,
        consent_text: consent_text,
        
        # Pass IP, user agent, and referrer for activity logging and lead data
        ip_address: ip_address,
        user_agent: user_agent,
        referrer: metadata['referrer'],
        
        # DO NOT add the source token as a parameter
        # It's now included in the API request headers
      })
      
      submission_service = LeadSubmissionService.new(
        source, 
        campaign, 
        submission_params
      )
      
      result = submission_service.process!
      
      # Create a processing log to track the result
      processing_log = {
        timestamp: Time.current.to_s,
        event: 'lead_submission_result',
        success: result[:success],
        source_id: source.id,
        campaign_id: campaign.id,
        api_request_id: api_request.id
      }
      
      if result[:success]
        # Update the processing log with success details
        processing_log.merge!({
          lead_id: result[:lead].id,
          processing_time: result[:processing_time],
          lead_status: result[:lead].status
        })
        
        # Update the API request to associate it with the lead
        api_request.update(lead: result[:lead])
        
        # Update the submission with lead information
        update(
          status: 'completed',
          lead_id: result[:lead].id,
          metadata: metadata.merge(
            lead_id: result[:lead].id,
            api_request_id: api_request.id,
            processing_time: result[:processing_time],
            processing_log: processing_log
          )
        )
      else
        # Update the processing log with error details
        processing_log.merge!({
          error: result[:error],
          errors: result[:errors],
          validation_errors: result[:validation_errors]
        })
        
        # Capture additional validation details if available
        if result[:lead]&.validation_rule_results.present?
          processing_log[:validation_rule_results] = result[:lead].validation_rule_results
        end
        
        # Update with error information
        update(
          status: 'rejected',
          metadata: metadata.merge(
            error: result[:error],
            errors: result[:errors],
            validation_errors: result[:validation_errors],
            api_request_id: api_request.id,
            processing_log: processing_log
          )
        )
      end
      
      # Log the processing result
      Rails.logger.info("Form submission ##{id} processing result: #{result[:success] ? 'Success' : 'Failed'}")
      if !result[:success]
        Rails.logger.info("Form submission ##{id} error: #{result[:error]}")
      end
    rescue => e
      # Handle any errors
      update(
        status: 'error',
        metadata: metadata.merge(
          error: e.message,
          backtrace: e.backtrace.first(5)
        )
      )
    end
  end
  
  # Track form analytics
  def track_analytics!
    # Skip if no time data available
    return unless metadata['time_data'].present?
    
    # Get or create analytics for today
    date = Date.current
    analytics = form_builder.analytics.find_or_initialize_by(date: date)
    
    # Increment appropriate counters
    analytics.submissions += 1
    analytics.completions += 1 if status == 'completed'
    
    # Add time on form if available
    if metadata['time_data']['total_time'].present?
      analytics.total_time_on_form_seconds += metadata['time_data']['total_time'].to_i
    end
    
    # Track field dropoffs if available
    if metadata['time_data']['field_dropoffs'].present?
      field_dropoffs = analytics.field_dropoffs || {}
      
      metadata['time_data']['field_dropoffs'].each do |field_id, count|
        field_dropoffs[field_id] ||= 0
        field_dropoffs[field_id] += count.to_i
      end
      
      analytics.field_dropoffs = field_dropoffs
    end
    
    # Track device info if available
    if metadata['device_info'].present?
      device_breakdown = analytics.device_breakdown || {}
      device_type = metadata['device_info']['device_type'] || 'unknown'
      
      device_breakdown[device_type] ||= 0
      device_breakdown[device_type] += 1
      
      analytics.device_breakdown = device_breakdown
    end
    
    # Save analytics
    analytics.save!
  end
end