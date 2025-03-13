puts "Creating lead activities for the Activity Feed..."

# ------------------------------
# Setup initial data
# ------------------------------

# Find an account to use
account = Account.first || Account.create!(name: "Demo Account")

# Find an admin user or create one
admin_user = User.joins(:account_users)
          .where(account_users: { account_id: account.id })
          .where("account_users.roles @> ?", {admin: true}.to_json)
          .first

if admin_user.nil?
  admin_user = User.create!(
    email: "admin@example.com",
    password: "password",
    password_confirmation: "password",
    first_name: "Admin",
    last_name: "User",
    terms_of_service: true,
    accepted_terms_at: Time.current,
    accepted_privacy_at: Time.current
  )
  AccountUser.create!(
    account: account,
    user: admin_user,
    roles: { admin: true }
  )
end

# Find support user or create one
support_user = User.joins(:account_users)
          .where(account_users: { account_id: account.id })
          .where("account_users.roles @> ?", {member: true}.to_json)
          .where.not("account_users.roles @> ?", {admin: true}.to_json)
          .first

if support_user.nil?
  support_user = User.create!(
    email: "support@example.com",
    password: "password",
    password_confirmation: "password",
    first_name: "Support",
    last_name: "User",
    terms_of_service: true,
    accepted_terms_at: Time.current,
    accepted_privacy_at: Time.current
  )
  AccountUser.create!(
    account: account,
    user: support_user,
    roles: { member: true }
  )
end

# Get or create campaigns
campaigns = account.campaigns.limit(3).to_a
if campaigns.size < 3
  campaign_names = ["Mortgage Leads", "Auto Insurance", "Health Insurance"]
  (0...3).each do |i|
    campaigns << account.campaigns.create!(
      name: campaign_names[i] || "Campaign #{i}",
      description: "A campaign for #{campaign_names[i] || "campaign #{i}"}",
      status: "active",
      campaign_type: "ping_post",
      distribution_method: "highest_bid",
      vertical: account.verticals.first || account.verticals.create!(name: "Finance", description: "Financial services vertical"),
      bid_timeout_seconds: 60,
      multi_distribution_strategy: "single",
      max_distributions: 1
    )
  end
end

# Get or create sources
sources = account.sources.limit(3).to_a
if sources.size < 3
  source_names = ["Website Form", "Email Campaign", "Social Media"]
  (0...3).each do |i|
    sources << account.sources.create!(
      name: source_names[i] || "Source #{i}",
      integration_type: "api",
      api_token: SecureRandom.hex(16),
      campaign: campaigns.sample
    )
  end
end

# Get or create distributions
distributions = account.distributions.limit(3).to_a
if distributions.size < 3
  distribution_names = ["Premium Buyer", "Standard Buyer", "Value Buyer"]
  (0...3).each do |i|
    distributions << account.distributions.create!(
      name: distribution_names[i] || "Distribution #{i}",
      endpoint_url: "https://example.com/api/leads",
      request_method: "post",
      request_format: "json",
      status: "active",
      bidding_strategy: "manual",
      base_bid_amount: 25.0 + (i * 10.0),
      company: account.companies.first || account.companies.create!(name: "Demo Company", account: account)
    )
  end
end

# Create campaign_distributions
campaigns.each do |campaign|
  distributions.each do |distribution|
    # Skip if already exists
    next if CampaignDistribution.exists?(campaign: campaign, distribution: distribution)
    
    CampaignDistribution.create!(
      campaign: campaign,
      distribution: distribution,
      active: true,
      priority: rand(1..10),
      account: account,
      last_used_at: rand(1..48).hours.ago
    )
  end
end

# ------------------------------
# Generate lead activities
# ------------------------------

# Use the LeadActivityService class methods

# Create a set of leads with full activity history
lead_count = 20
puts "Creating #{lead_count} leads with complete activity timelines..."

lead_count.times do |i|
  # Determine if this lead should have a successful journey or errors
  success_journey = rand(10) < 8 # 80% success rate
  
  # Create a lead with a random timestamp within the last 7 days
  created_time = rand(10.minutes..7.days).ago
  
  lead = Lead.create!(
    campaign: campaigns.sample,
    source: sources.sample,
    status: success_journey ? :distributed : [:error, :rejected].sample,
    account: account,
    unique_id: SecureRandom.uuid,
    ip_address: "192.168.#{rand(1..255)}.#{rand(1..255)}",
    user_agent: ["Mozilla/5.0 (Macintosh)", "Mozilla/5.0 (Windows)", "Mozilla/5.0 (iPhone)"].sample,
    created_at: created_time,
    updated_at: created_time
  )
  
  # Record initial submission (always succeeds)
  submission_time = created_time
  LeadActivityService.record_submission(lead, {
    source_id: lead.source_id,
    source_name: lead.source&.name,
    campaign_id: lead.campaign_id,
    campaign_name: lead.campaign&.name,
    source_ip: lead.ip_address,
    source_user_agent: lead.user_agent,
    referrer: ["https://example.com", "https://google.com", "https://facebook.com", "https://twitter.com"].sample,
    created_at: submission_time
  })
  
  # Record validation (may fail)
  validation_time = submission_time + rand(1..15).seconds
  validation_success = success_journey || (rand(10) < 8) # Higher success rate
  LeadActivityService.record_validation(lead, {
    valid: validation_success,
    validation_type: "campaign_rules",
    validations_passed: validation_success ? rand(3..7) : rand(0..2),
    validations_failed: validation_success ? 0 : rand(1..3),
    validators: ["required_fields", "email_format", "phone_format", "age_check", "zip_code"],
    errors: validation_success ? [] : ["Missing required field", "Invalid email format", "Phone number invalid"].sample(rand(1..2)),
    created_at: validation_time
  })
  
  # If validation failed, skip the rest (unless this is a success journey)
  next if !validation_success && !success_journey
  
  # Record status update to processing
  status_time = validation_time + rand(1..5).seconds
  LeadActivityService.record_status_update(lead, "new_lead", "processing", {
    reason: "Lead passed validation",
    next_step: "bidding",
    created_at: status_time
  })
  
  # Record anonymization for bidding
  anon_time = status_time + rand(1..5).seconds
  LeadActivityService.record_anonymization(lead, {
    anonymization_type: "bidding_preparation",
    fields_anonymized: ["email", "phone", "first_name", "last_name"],
    anonymization_method: "hash",
    created_at: anon_time
  })
  
  # Create a bid request
  bid_request_time = anon_time + rand(1..5).seconds
  bid_request = BidRequest.create!(
    account: account,
    campaign: lead.campaign,
    lead: lead,
    anonymized_data: { 
      zip: ["90210", "10001", "60601", "75001", "98101"].sample, 
      age_range: ["18-24", "25-34", "35-44", "45-54", "55+"].sample, 
      income_range: ["<$30k", "$30k-$50k", "$50k-$75k", "$75k-$100k", "$100k+"].sample
    },
    bid_metadata: { lead_id: lead.unique_id, campaign_id: lead.campaign_id },
    status: success_journey ? :completed : [:active, :expired, :canceled].sample,
    expires_at: success_journey ? (bid_request_time + 2.minutes) : (bid_request_time + rand(10..60).seconds),
    created_at: bid_request_time,
    updated_at: bid_request_time,
    completed_at: success_journey ? (bid_request_time + rand(30..90).seconds) : nil
  )
  
  # Record bid request creation
  LeadActivityService.record_bid_request(lead, bid_request, {
    ping_fields: ["zip", "age_range", "income_range"],
    timeout_seconds: 120,
    expiration_time: bid_request.expires_at,
    created_at: bid_request_time
  })
  
  # Generate 0-3 bids (if the request wasn't canceled)
  if bid_request.status != 'canceled'
    num_bids = success_journey ? rand(1..3) : rand(0..2)
    
    bids = []
    
    # Generate bids
    num_bids.times do |j|
      # Generate bid time (random interval after bid request creation)
      bid_time = bid_request_time + rand(5..45).seconds
      next if bid_time > bid_request.expires_at # Skip if after expiration
      
      # Select a distribution
      distribution = distributions.sample
      
      # Check if a bid already exists for this distribution and bid request
      existing_bid = Bid.find_by(bid_request: bid_request, distribution: distribution)
      
      if existing_bid
        # Use the existing bid
        bid = existing_bid
      else
        # Create a new bid
        bid = Bid.create!(
          bid_request: bid_request,
          distribution: distribution,
          amount: (15.0 + rand(5..35) + rand(0..99)/100.0).round(2), # $15-$50 bid with cents
          account: account,
          status: :pending,
          created_at: bid_time,
          updated_at: bid_time
        )
      end
      
      bids << bid
      
      # Record bid received
      LeadActivityService.record_bid_received(lead, bid, {
        buyer_name: distribution.name,
        buyer_type: distribution.request_format,
        created_at: bid_time
      })
    end
    
    # If no bids received on a success journey, create one
    if bids.empty? && success_journey
      bid_time = bid_request_time + rand(10..30).seconds
      distribution = distributions.first
      
      # Check if a bid already exists for this distribution and bid request
      existing_bid = Bid.find_by(bid_request: bid_request, distribution: distribution)
      
      if existing_bid
        # Use the existing bid
        bid = existing_bid
      else
        # Create a new bid
        bid = Bid.create!(
          bid_request: bid_request,
          distribution: distribution,
          amount: (25.0 + rand(10..25)).round(2),
          account: account,
          status: :pending,
          created_at: bid_time,
          updated_at: bid_time
        )
      end
      
      bids << bid
      
      LeadActivityService.record_bid_received(lead, bid, {
        buyer_name: distribution.name,
        buyer_type: distribution.request_format,
        created_at: bid_time
      })
    end
    
    # If we have bids and this is a success journey, select a winner
    if !bids.empty? && success_journey
      # Find the winning bid (highest amount)
      winning_bid = bids.max_by(&:amount)
      winning_time = bid_request_time + rand(45..60).seconds
      
      # Update winning bid status
      winning_bid.update(
        status: :accepted,
        updated_at: winning_time
      )
      
      # Update other bids to rejected
      (bids - [winning_bid]).each do |bid|
        bid.update(
          status: :rejected,
          updated_at: winning_time
        )
      end
      
      # Record winning bid selection
      LeadActivityService.record_bid_selected(lead, winning_bid, {
        selection_method: "highest_bid",
        total_bids: bids.count,
        bid_request_id: bid_request.id,
        created_at: winning_time
      })
      
      # Record consent requested
      consent_request_time = winning_time + rand(2..10).seconds
      winning_distribution = winning_bid.distribution
      LeadActivityService.record_consent_requested(lead, winning_distribution, {
        consent_type: "distribution_consent",
        buyer_name: winning_distribution.name,
        buyer_type: winning_distribution.request_format,
        consent_message: "Do you agree to share your information with #{winning_distribution.name}?",
        created_at: consent_request_time
      })
      
      # Record consent provided
      consent_time = consent_request_time + rand(5..20).seconds
      
      # Check if consent already exists
      existing_consent = ConsentRecord.find_by(
        lead: lead,
        consent_type: "distribution_consent"
      )
      
      if existing_consent
        consent_record = existing_consent
      else
        consent_record = ConsentRecord.create!(
          lead: lead,
          account: account,
          uuid: SecureRandom.uuid,
          consent_type: "distribution_consent", 
          consent_text: "I agree to share my information with #{winning_distribution.name}",
          ip_address: lead.ip_address,
          user_agent: lead.user_agent,
          revoked: false,
          consented_at: consent_time,
          created_at: consent_time,
          updated_at: consent_time
        )
      end
      
      LeadActivityService.record_consent_provided(lead, consent_record, {
        buyer_name: winning_distribution.name,
        buyer_type: winning_distribution.request_format,
        consent_timestamp: consent_time,
        created_at: consent_time
      })
      
      # Record distribution
      distribution_time = consent_time + rand(2..15).seconds
      response_success = rand(10) < 9 # 90% success
      
      # Check if an API request already exists for this lead and distribution
      existing_api_request = ApiRequest.find_by(lead: lead, requestable: winning_distribution)
      
      if existing_api_request
        # Use the existing API request
        api_request = existing_api_request
      else
        # Create a new API request
        api_request = ApiRequest.create!(
          requestable: winning_distribution,
          lead: lead,
          account: account,
          endpoint_url: winning_distribution.endpoint_url,
          request_method: "post",
          request_payload: { lead_data: "sample data" }.to_json,
          response_code: response_success ? 200 : [400, 422, 500].sample,
          response_payload: response_success ? 
                         { success: true, lead_id: "DIST-#{SecureRandom.hex(4)}" }.to_json : 
                         { success: false, error: "Invalid data format" }.to_json,
          duration_ms: rand(150..800),
          sent_at: distribution_time,
          created_at: distribution_time,
          updated_at: distribution_time
        )
      end
      
      LeadActivityService.record_distribution(lead, api_request, {
        distribution_id: winning_distribution.id,
        distribution_name: winning_distribution.name,
        distribution_type: winning_distribution.request_format,
        endpoint_url: winning_distribution.endpoint_url,
        request_method: "post",
        response_code: api_request.response_code,
        created_at: distribution_time
      })
      
      # Record buyer response
      response_time = distribution_time + rand(1..5).seconds
      LeadActivityService.record_buyer_response(lead, api_request, {
        distribution_id: winning_distribution.id,
        distribution_name: winning_distribution.name,
        response_status: response_success ? "accepted" : "rejected",
        response_time: api_request.duration_ms / 1000.0,
        response_data: api_request.response_payload.is_a?(String) ? 
                      JSON.parse(api_request.response_payload) : api_request.response_payload,
        created_at: response_time
      })
      
      # Update campaign_distribution's last_used_at
      camp_dist = CampaignDistribution.find_by(campaign: lead.campaign, distribution: winning_distribution)
      camp_dist.update(last_used_at: distribution_time) if camp_dist
      
      # Record final status update
      status_update_time = response_time + rand(1..5).seconds
      final_status = response_success ? "distributed" : "error"
      
      LeadActivityService.record_status_update(lead, "processing", final_status, {
        reason: response_success ? "Successfully distributed to buyer" : "Error during distribution",
        distribution_id: winning_distribution.id,
        distribution_name: winning_distribution.name,
        created_at: status_update_time
      })
      
      # Update lead status
      lead.update(status: final_status, updated_at: status_update_time)
      
      # 20% chance of data access record by admin
      if rand(5) == 0
        access_time = status_update_time + rand(1.minute..24.hours)
        LeadActivityService.record_data_access(lead, [admin_user, support_user].sample, {
          access_type: ["view", "export", "download"].sample,
          fields_accessed: ["all", "basic", "contact"].sample,
          reason: ["Account review", "Export for reports", "Customer support inquiry"].sample,
          access_context: ["admin", "reporting", "customer_support"].sample,
          created_at: access_time
        })
      end
    elsif !bids.empty? && !success_journey
      # For unsuccessful journeys with bids, expire them
      expire_time = bid_request.expires_at
      bids.each do |bid|
        bid.update(status: :expired, updated_at: expire_time)
      end
      
      # Mark bid request as expired
      bid_request.update(status: :expired, updated_at: expire_time)
      
      # Record status update to error
      error_time = expire_time + rand(1..5).seconds
      LeadActivityService.record_status_update(lead, "processing", "error", {
        reason: "Bidding timed out with no accepted bids",
        created_at: error_time
      })
      
      # Update lead status
      lead.update(status: :error, updated_at: error_time)
    elsif bids.empty? && !success_journey
      # For unsuccessful journeys with no bids, cancel the bid request
      cancel_time = bid_request_time + rand(30..60).seconds
      
      # Mark bid request as canceled
      bid_request.update(status: :canceled, updated_at: cancel_time)
      
      # Record status update to rejected
      rejection_time = cancel_time + rand(1..5).seconds
      LeadActivityService.record_status_update(lead, "processing", "rejected", {
        reason: "No bids received from buyers",
        created_at: rejection_time
      })
      
      # Update lead status
      lead.update(status: :rejected, updated_at: rejection_time)
    end
  end
  
  print "." if i % 5 == 0 # Progress indicator
end

puts "\nCreated activities for #{lead_count} leads with #{LeadActivityLog.count} total activities"
puts "Created #{Lead.where(status: :distributed).count} successfully distributed leads"
puts "Created #{Lead.where(status: [:error, :rejected]).count} failed leads"
puts "Created #{Bid.count} bids with #{Bid.where(status: :accepted).count} accepted"
puts "Created #{ConsentRecord.count} consent records"
puts "Created #{ApiRequest.count} API requests"