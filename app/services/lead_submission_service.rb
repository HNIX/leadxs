# app/services/lead_submission_service.rb
class LeadSubmissionService
  def initialize(source, campaign, params)
    @source = source
    @campaign = campaign
    @params = params
    @lead = nil
    @validation_errors = []
  end
  
  def process!
    # Create the lead record with basic information
    create_lead
    
    # Return early if lead creation failed
    return { success: false, message: 'Failed to create lead', errors: @lead.errors.full_messages } if @lead.nil?
    
    # Parse and store the lead data fields
    store_lead_data
    
    # Validate the lead against campaign rules
    @validation_errors = @lead.validate_against_rules
    
    # Decide next steps based on validation and campaign configuration
    if @validation_errors.empty?
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
    # Process each campaign field
    @campaign.campaign_fields.each do |field|
      # Get the value from params
      field_value = @params[field.name] || @params[field.name.underscore] || @params[field.name.parameterize(separator: '_')]
      
      # Skip if no value provided and field is not required
      next if field_value.blank? && !field.required?
      
      # Store the value
      @lead.lead_data.create!(
        campaign_field: field,
        value: field_value
      )
    end
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
    
    # Create a distribution service
    distribution_service = LeadDistributionService.new(@lead)
    
    # Distribute the lead
    result = distribution_service.distribute!
    
    if result[:success]
      # Update lead status to distributed
      @lead.update(status: :distributed)
      
      { 
        success: true, 
        lead: @lead, 
        message: 'Lead submitted and distributed successfully' 
      }
    else
      # Update lead status to error
      @lead.update(status: :error)
      
      { 
        success: false, 
        lead: @lead, 
        message: result[:message] || 'Failed to distribute lead' 
      }
    end
  end
  
  def handle_invalid_lead
    # Format validation errors
    errors = @validation_errors.map do |error|
      "#{error[:rule].name}: #{error[:message]}"
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