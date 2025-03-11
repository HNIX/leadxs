puts "Creating lead activity logs..."

# Find an account to use
account = Account.first || Account.create!(name: "Test Account")

# Find a user for the activity logs
user = User.first || User.create!(
  email: "test@example.com",
  password: "password",
  password_confirmation: "password",
  first_name: "Test",
  last_name: "User",
  terms_of_service: true,
  accepted_terms_at: Time.current,
  accepted_privacy_at: Time.current
)

# Find or create a campaign
campaign = Campaign.where(account: account).first || 
  Campaign.create!(
    name: "Test Campaign",
    account: account,
    description: "A test campaign",
    status: "active"
  )

# Find or create some leads
leads = Lead.where(campaign: campaign).limit(20).to_a

if leads.empty?
  5.times do |i|
    leads << Lead.create!(
      account: account,
      campaign: campaign,
      status: "new",
      unique_id: SecureRandom.uuid,
      ip_address: "127.0.0.1",
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
      referrer: "https://example.com"
    )
  end
end

# For each lead, create a sequence of activity logs
leads.each do |lead|
  # Submission
  LeadActivityLog.create!(
    lead: lead,
    user: nil,
    account: account,
    activity_type: "submission",
    details: {
      source: "web form",
      campaign_id: lead.campaign_id,
      campaign_name: lead.campaign.name
    },
    created_at: 1.hour.ago
  )
  
  # Validation
  LeadActivityLog.create!(
    lead: lead,
    user: nil,
    account: account,
    activity_type: "validation",
    details: {
      valid: true,
      validations_passed: 5,
      validations_failed: 0
    },
    created_at: 55.minutes.ago
  )
  
  # Anonymization
  LeadActivityLog.create!(
    lead: lead,
    user: nil,
    account: account,
    activity_type: "anonymization",
    details: {
      fields_anonymized: ["email", "phone", "first_name", "last_name"],
      anonymization_method: "hash"
    },
    created_at: 50.minutes.ago
  )
  
  # Bid request
  bid_request_id = rand(1000..9999)
  LeadActivityLog.create!(
    lead: lead,
    user: nil,
    account: account,
    activity_type: "bid_request",
    details: {
      bid_request_id: bid_request_id,
      ping_fields: ["zip", "age", "income"],
      buyer_count: 5,
      expiration: 5.minutes
    },
    created_at: 45.minutes.ago
  )
  
  # Bid received (1)
  bid1_id = rand(1000..9999)
  LeadActivityLog.create!(
    lead: lead,
    user: nil,
    account: account,
    activity_type: "bid_received",
    details: {
      bid_id: bid1_id,
      bid_request_id: bid_request_id,
      buyer_id: 123,
      buyer_name: "Buyer A",
      amount: 25.50
    },
    created_at: 43.minutes.ago
  )
  
  # Bid received (2)
  bid2_id = rand(1000..9999)
  LeadActivityLog.create!(
    lead: lead,
    user: nil,
    account: account,
    activity_type: "bid_received",
    details: {
      bid_id: bid2_id,
      bid_request_id: bid_request_id,
      buyer_id: 456,
      buyer_name: "Buyer B",
      amount: 30.75
    },
    created_at: 41.minutes.ago
  )
  
  # Winning bid selected
  LeadActivityLog.create!(
    lead: lead,
    user: nil,
    account: account,
    activity_type: "bid_selected",
    details: {
      bid_id: bid2_id,
      bid_request_id: bid_request_id,
      buyer_id: 456,
      buyer_name: "Buyer B",
      amount: 30.75,
      selection_method: "highest_bid"
    },
    created_at: 40.minutes.ago
  )
  
  # Consent requested
  LeadActivityLog.create!(
    lead: lead,
    user: nil,
    account: account,
    activity_type: "consent_requested",
    details: {
      buyer_id: 456,
      buyer_name: "Buyer B",
      consent_type: "buyer_specific",
      consent_message: "Do you agree to share your information with Buyer B for the purpose of receiving mortgage offers?"
    },
    created_at: 38.minutes.ago
  )
  
  # Consent provided
  consent_record_id = rand(1000..9999)
  LeadActivityLog.create!(
    lead: lead,
    user: nil,
    account: account,
    activity_type: "consent_provided",
    details: {
      consent_record_id: consent_record_id,
      consent_type: "buyer_specific",
      verification_method: "checkbox",
      consent_timestamp: 37.minutes.ago
    },
    created_at: 37.minutes.ago
  )
  
  # Distribution
  distribution_id = rand(1000..9999)
  LeadActivityLog.create!(
    lead: lead,
    user: nil,
    account: account,
    activity_type: "distribution",
    details: {
      distribution_id: distribution_id,
      buyer_id: 456,
      buyer_name: "Buyer B",
      distribution_method: "api_post",
      endpoint_url: "https://api.buyerb.example.com/leads"
    },
    created_at: 35.minutes.ago
  )
  
  # Buyer response
  LeadActivityLog.create!(
    lead: lead,
    user: nil,
    account: account,
    activity_type: "buyer_response",
    details: {
      distribution_id: distribution_id,
      buyer_id: 456,
      buyer_name: "Buyer B",
      response_status: "accepted",
      response_time: 1.2,
      response_data: {
        lead_id: "B-#{rand(10000..99999)}",
        message: "Lead accepted",
        duplicates_found: 0
      }
    },
    created_at: 34.minutes.ago
  )
  
  # Status update
  LeadActivityLog.create!(
    lead: lead,
    user: nil,
    account: account,
    activity_type: "status_update",
    details: {
      old_status: "processing",
      new_status: "distributed",
      reason: "Successfully distributed to Buyer B"
    },
    created_at: 33.minutes.ago
  )
  
  # Data access (by admin)
  LeadActivityLog.create!(
    lead: lead,
    user: user,
    account: account,
    activity_type: "data_access",
    details: {
      access_type: "view",
      fields_accessed: "all",
      reason: "Administrative review"
    },
    created_at: 20.minutes.ago
  )
end

puts "Created #{LeadActivityLog.count} lead activity logs"