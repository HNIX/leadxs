# app/services/lead_submission_service.rb
class LeadSubmissionService
  def initialize(source, campaign, params)
    @source = source
    @campaign = campaign
    @params = params
    @lead = nil
    @validation_errors = {}
    @processed_data = {}
  end
  
  def process!
    # Create the lead record with basic information
    create_lead
    
    # Return early if lead creation failed
    return { success: false, message: 'Failed to create lead', errors: @lead.errors.full_messages } if @lead.nil?
    
    # Parse and store the lead data fields
    store_lead_data
    
    # Process the lead data (normalize, calculate fields, enrich)
    process_lead_data
    
    # Validate the lead against campaign rules
    @validation_errors = @lead.validate_against_rules
    
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
    @lead = @source.leads.new(
      campaign: @campaign,
      status: :new_lead,
      account: @source.account
    )
    
    # Return false if save fails
    return false unless @lead.save
    
    # Return the lead
    @lead
  end
  
  def store_lead_data
    initial_data = {}
    
    # Process each campaign field
    @campaign.campaign_fields.each do |field|
      # Get the value from params using various possible naming conventions
      field_value = @params[field.name] || 
                   @params[field.name.underscore] || 
                   @params[field.name.parameterize(separator: '_')]
      
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
    @lead.update(status: :processing)
    
    if @campaign.use_bidding_system?
      # Process through bidding system
      process_through_bidding
    else
      # Direct distribution to endpoints
      process_through_direct_distribution
    end
  end
  
  def process_through_bidding
    # Create a bid service
    bid_service = BidService.new(@lead, @campaign)
    
    # Create a bid request and solicit bids
    bid_request = bid_service.solicit_bids!
    
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
    
    # Update lead status to rejected
    @lead.update(status: :rejected)
    
    { 
      success: false, 
      lead: @lead, 
      message: 'Lead failed validation', 
      errors: errors 
    }
  end
end