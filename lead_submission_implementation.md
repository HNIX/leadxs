# Lead Submission Process - Technical Implementation

This document maps the LeadXS lead submission process to the actual code implementation, showing how each step in the process flow is handled by specific files and methods in our application.

## Overview of the Process

The lead submission process involves these primary steps:
1. Receiving and authenticating lead submissions through the API
2. Validating and normalizing the lead data
3. Processing the lead through bidding (for ping-post campaigns) or direct distribution
4. Delivering the lead to buyers and tracking the results
5. Monitoring and logging for compliance and analytics

## 1. Lead Submission and API Authentication

### API Endpoint Reception

**Implementation Files:**
- `/app/controllers/api/v1/lead_posts_controller.rb`

**Key Methods:**
- `Api::V1::LeadPostsController#create`

When a lead is submitted to the `/api/v1/lead_posts` endpoint, the `LeadPostsController#create` method is triggered. This controller handles the initial authentication, lead processing, and the appropriate API response.

```ruby
# app/controllers/api/v1/lead_posts_controller.rb
def create
  authenticate_source
  result = LeadSubmissionService.new(current_source, lead_params).process!
  
  if result.success?
    render json: success_response(result.lead)
  else
    render json: error_response(result.errors), status: :unprocessable_entity
  end
end
```

### Source Authentication and Verification

**Implementation Files:**
- `/app/controllers/api/v1/lead_posts_controller.rb`
- `/app/models/source.rb`

**Key Methods:**
- `LeadPostsController#authenticate_source`
- `Source#active?`
- `Source#can_submit_leads?`

The controller verifies the source token from the request headers, checks if the source is active, and sets up multi-tenancy.

```ruby
# app/controllers/api/v1/lead_posts_controller.rb
def authenticate_source
  token = request.headers['X-Source-Token'] || params[:source_token]
  @current_source = Source.find_by(api_token: token)
  
  if @current_source.nil? || !@current_source.active?
    render json: { success: false, message: "Invalid source token" }, status: :unauthorized
    return
  end
  
  # Set current tenant (account) for the request
  ActsAsTenant.current_tenant = @current_source.account
end
```

## 2. Initial Lead Processing and Validation

### Lead Creation and Field Mapping

**Implementation Files:**
- `/app/services/lead_submission_service.rb`
- `/app/models/lead.rb`
- `/app/models/campaign.rb`

**Key Methods:**
- `LeadSubmissionService#process!`
- `LeadSubmissionService#create_lead`
- `LeadSubmissionService#store_lead_data`

The `LeadSubmissionService` orchestrates the entire process, starting with creating a lead record and mapping submitted data to campaign fields.

```ruby
# app/services/lead_submission_service.rb
def process!
  # Create lead record with initial status
  @lead = create_lead
  
  # Store field values from the submitted data
  store_lead_data
  
  # Validate the lead against campaign rules
  if @lead.valid_for_processing?
    process_valid_lead
  else
    handle_invalid_lead
  end
  
  # Return result object with lead and status
  SubmissionResult.new(@lead, success?)
end
```

### Validation Against Campaign Rules

**Implementation Files:**
- `/app/models/lead.rb`
- `/app/models/validation_rule.rb`
- `/app/services/validation_rule_processor.rb`

**Key Methods:**
- `Lead#validate_against_rules`
- `ValidationRuleProcessor#evaluate`

The lead data is validated against the campaign's validation rules to ensure quality and compliance.

```ruby
# app/models/lead.rb
def validate_against_rules
  campaign.validation_rules.active.ordered.each do |rule|
    result = ValidationRuleProcessor.new(rule, self.field_values_hash).evaluate
    
    if !result.valid?
      self.errors.add(:validation_rules, "#{rule.name}: #{result.message}")
      self.validation_failures[rule.id] = result.message
    end
  end
  
  self.validation_failures.empty?
end
```

### Data Normalization and Enrichment

**Implementation Files:**
- `/app/services/lead_data_processor.rb`
- `/app/models/calculated_field.rb`

**Key Methods:**
- `LeadDataProcessor#normalize`
- `LeadDataProcessor#calculate_fields`

The lead data undergoes normalization and enrichment, including processing of calculated fields.

```ruby
# app/services/lead_data_processor.rb
def normalize
  normalize_phone_numbers
  normalize_address_fields
  standardize_dates
  trim_whitespace
end

def calculate_fields
  @campaign.calculated_fields.each do |field|
    # Calculate value based on formula and normalized lead data
    value = FormulaEvaluator.evaluate(field.formula, @lead_data)
    @lead_data[field.id] = value
  end
end
```

## 3. Bidding Process for Ping-Post Campaigns

### Bid Request Creation

**Implementation Files:**
- `/app/services/bid_service.rb`
- `/app/models/bid_request.rb`

**Key Methods:**
- `BidService#create_bid_request`
- `BidService#prepare_anonymized_data`

For ping-post campaigns, the system creates a bid request with anonymized lead data.

```ruby
# app/services/bid_service.rb
def create_bid_request
  anonymized_data = prepare_anonymized_data
  
  @bid_request = BidRequest.create!(
    lead: @lead,
    campaign: @campaign,
    anonymized_data: anonymized_data,
    expires_at: Time.current + @campaign.bid_timeout.seconds
  )
end

def prepare_anonymized_data
  # Filter out PII fields and only include shareable fields
  @lead.field_values_hash.select do |field_id, value|
    field = @campaign.find_field(field_id)
    field && field.share_during_bidding?
  end
end
```

### Bid Solicitation and Collection

**Implementation Files:**
- `/app/services/bid_service.rb`
- `/app/models/distribution.rb`
- `/app/jobs/solicit_bid_job.rb`

**Key Methods:**
- `BidService#solicit_bids!`
- `Distribution#request_bid`

The system solicits bids from eligible distributions by sending anonymized lead data.

```ruby
# app/services/bid_service.rb
def solicit_bids!
  eligible_distributions = @campaign.eligible_distributions_for_bidding(@lead)
  
  eligible_distributions.each do |distribution|
    # Send asynchronously to all distributions in parallel
    SolicitBidJob.perform_later(@bid_request.id, distribution.id)
  end
  
  # Return the bid request for tracking
  @bid_request
end

# app/jobs/solicit_bid_job.rb
def perform(bid_request_id, distribution_id)
  bid_request = BidRequest.find(bid_request_id)
  distribution = Distribution.find(distribution_id)
  
  # Only proceed if the bid request is still active
  return if bid_request.completed? || bid_request.expired?
  
  # Request bid from the distribution
  response = distribution.request_bid(bid_request.anonymized_data)
  
  # Record the bid
  if response.success? && response.bid_amount.present?
    Bid.create!(
      bid_request: bid_request,
      distribution: distribution,
      amount: response.bid_amount,
      metadata: response.metadata
    )
  end
end
```

### Winner Selection

**Implementation Files:**
- `/app/models/bid_request.rb`
- `/app/services/bid_selection_service.rb`

**Key Methods:**
- `BidRequest#complete_bidding!`
- `BidSelectionService#select_winner`

After collecting bids, the system selects a winner based on the campaign's distribution method.

```ruby
# app/models/bid_request.rb
def complete_bidding!
  return if completed?
  
  # Lock record to prevent race conditions
  with_lock do
    # Select winning bid based on campaign distribution method
    winning_bid = BidSelectionService.new(self).select_winner
    
    if winning_bid.present?
      winning_bid.accept!
      update!(status: 'completed', winning_bid_id: winning_bid.id)
      
      # Distribute lead to the winning distribution
      LeadDistributionService.new(lead, winning_bid.distribution).distribute!
    else
      update!(status: 'no_bids')
      # Handle fallback for no bids
    end
  end
end

# app/services/bid_selection_service.rb
def select_winner
  case @campaign.distribution_method
  when 'highest_bid'
    select_highest_bidder
  when 'weighted_random'
    select_weighted_random
  when 'waterfall'
    select_by_waterfall
  else
    select_highest_bidder # Default
  end
end
```

## 4. Lead Distribution

### Final Lead Preparation

**Implementation Files:**
- `/app/services/lead_distribution_service.rb`
- `/app/models/field_mapper.rb`

**Key Methods:**
- `LeadDistributionService#build_payload`
- `FieldMapper#map_fields`

The system prepares the complete lead data package for distribution to the buyer.

```ruby
# app/services/lead_distribution_service.rb
def build_payload
  # Get complete lead data
  lead_data = @lead.field_values_hash
  
  # Map field names to match distribution requirements
  mapped_data = FieldMapper.new(@distribution, lead_data).map_fields
  
  # Add any required metadata
  mapped_data.merge({
    lead_id: @lead.uuid,
    campaign_id: @lead.campaign.external_id,
    source_id: @lead.source.external_id,
    timestamp: Time.current.iso8601
  })
end
```

### API Request Submission

**Implementation Files:**
- `/app/services/lead_distribution_service.rb`
- `/app/models/api_request.rb`

**Key Methods:**
- `LeadDistributionService#send_to_distribution`
- `ApiClient#post`

The system sends the lead data to the distribution's endpoint and processes the response.

```ruby
# app/services/lead_distribution_service.rb
def send_to_distribution(payload)
  client = ApiClient.new(@distribution.endpoint_url, @distribution.auth_headers)
  
  # Send API request
  response = client.post(payload, timeout: @distribution.timeout)
  
  # Record API request and response
  api_request = record_api_request(payload, response)
  
  # Update lead status based on response
  if response.success?
    @lead.update!(
      status: 'distributed',
      distributed_at: Time.current,
      distribution_id: @distribution.id
    )
  else
    @lead.update!(
      status: 'distribution_error',
      distribution_error: response.error_message
    )
  end
  
  api_request
end
```

### Multiple Distribution Handling

**Implementation Files:**
- `/app/services/multi_distribution_service.rb`

**Key Methods:**
- `MultiDistributionService#distribute!`
- `MultiDistributionService#process_waterfall`

For campaigns configured for multi-distribution, the system handles sequential or parallel distribution.

```ruby
# app/services/multi_distribution_service.rb
def distribute!
  case @campaign.multi_distribution_strategy
  when 'waterfall'
    process_waterfall
  when 'parallel'
    process_parallel
  end
end

def process_waterfall
  @campaign.distributions.ordered.each do |distribution|
    result = LeadDistributionService.new(@lead, distribution).distribute!
    
    # Stop if distribution was successful
    return result if result.success?
  end
  
  # If no successful distribution, mark lead as failed
  @lead.update!(status: 'distribution_failed')
end
```

## 5. Compliance and Tracking

### Compliance Documentation

**Implementation Files:**
- `/app/models/compliance_record.rb`
- `/app/services/compliance_service.rb`

**Key Methods:**
- `ComplianceService#log_consent_record`
- `ComplianceService#log_data_access`

The system creates detailed compliance records for regulatory purposes.

```ruby
# app/services/compliance_service.rb
def log_consent_record
  ConsentRecord.create!(
    lead: @lead,
    ip_address: @lead_data[:ip_address],
    timestamp: Time.current,
    consent_text: @campaign.consent_disclosure_text,
    consent_version: @campaign.consent_version
  )
end

def log_data_access(user, action, accessed_fields)
  DataAccessRecord.create!(
    lead: @lead,
    user: user,
    action: action,
    accessed_fields: accessed_fields,
    timestamp: Time.current
  )
end
```

### Comprehensive Activity Logging

**Implementation Files:**
- `/app/models/lead_event.rb`
- `/app/services/event_logging_service.rb`

**Key Methods:**
- `EventLoggingService#log_event`
- `LeadEvent#create_for_lead`

The system maintains a detailed chronological record of all lead-related events.

```ruby
# app/services/event_logging_service.rb
def log_event(event_type, details = {})
  LeadEvent.create!(
    lead: @lead,
    event_type: event_type,
    details: details,
    timestamp: Time.current
  )
end

# Usage examples:
# log_event('lead_created', {source: @lead.source.name})
# log_event('validation_failed', {rules: @lead.validation_failures})
# log_event('bid_requested', {bid_request_id: bid_request.id})
# log_event('distribution_attempted', {distribution: distribution.name})
```

### Performance Metrics Calculation

**Implementation Files:**
- `/app/services/analytics_service.rb`
- `/app/models/analytics/campaign_metric.rb`

**Key Methods:**
- `AnalyticsService#update_metrics`
- `CampaignMetric#calculate_for_period`

The system automatically updates performance metrics across various dimensions.

```ruby
# app/services/analytics_service.rb
def update_metrics
  # Update campaign metrics
  update_campaign_metrics
  
  # Update source metrics
  update_source_metrics
  
  # Update distribution metrics
  update_distribution_metrics
end

def update_campaign_metrics
  # Calculate metrics for different time periods
  %w[hourly daily weekly monthly].each do |period|
    CampaignMetric.calculate_for_period(@campaign, period)
  end
end
```

## Conclusion

This document provides a technical overview of how the lead submission process is implemented in the LeadXS application. Each component of the system works together to ensure efficient lead processing, optimal distribution, and comprehensive tracking for compliance and analytics purposes.

The modular architecture allows for flexibility in handling different campaign types, distribution methods, and validation rules, while maintaining consistency in lead processing and compliance documentation.