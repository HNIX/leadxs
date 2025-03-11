puts "Creating test lead with complete activity timeline..."

# Get a lead to work with
lead = Lead.first

# If there's no lead, create one
if lead.nil? || lead.lead_activity_logs.exists?
  account = Account.first
  campaign = Campaign.where(account: account).first
  source = Source.where(account: account).first || Source.create!(name: 'Test Source', account: account)
  
  lead = Lead.create!(
    campaign: campaign,
    source: source,
    status: :new_lead,
    account: account,
    unique_id: SecureRandom.uuid,
    ip_address: "127.0.0.1",
    user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
  )
  
  puts "Created new lead #{lead.id} for activity testing"
end

# Get the account admin user
user = User.joins(:account_users)
           .where(account_users: { account_id: lead.account_id })
           .where("account_users.roles @> ?", {admin: true}.to_json)
           .first

# Initialize activity service
lead_activity_service = LeadActivityService.new

# 1. Record submission - starting point
lead_activity_service.record_submission(lead, {
  source_id: lead.source_id,
  source_name: lead.source&.name || "Test Source",
  campaign_id: lead.campaign_id,
  campaign_name: lead.campaign&.name || "Test Campaign",
  source_ip: lead.ip_address,
  source_user_agent: lead.user_agent,
  referrer: "https://example.com/signup"
})

# 2. Record validation - success
lead_activity_service.record_validation(lead, {
  valid: true,
  validation_type: "campaign_rules",
  validations_passed: 5,
  validators: ["required_fields", "email_format", "phone_format", "age_check", "zip_code"]
})

# 3. Record status update - to processing
lead_activity_service.record_status_update(lead, "new_lead", "processing", {
  reason: "Lead passed validation",
  next_step: "bidding"
})

# 4. Record anonymization - before bidding
lead_activity_service.record_anonymization(lead, {
  anonymization_type: "bidding_preparation",
  fields_anonymized: ["email", "phone", "first_name", "last_name"],
  anonymization_method: "hash"
})

# 5. Create a bid request
bid_request = BidRequest.create!(
  account: lead.account,
  campaign: lead.campaign,
  lead: lead,
  anonymized_data: { zip: "90210", age_range: "25-34", income_range: "$50k-$75k" },
  bid_metadata: { lead_id: lead.unique_id, campaign_id: lead.campaign_id },
  status: :active,
  expires_at: 5.minutes.from_now
)

# 6. Record bid request creation
lead_activity_service.record_bid_request(lead, bid_request, {
  ping_fields: ["zip", "age_range", "income_range"],
  timeout_seconds: 120,
  expiration_time: bid_request.expires_at
})

# 7-8. Create bids and record bid received activities
buyers = [
  { name: "Buyer A", bid: 35.75 },
  { name: "Buyer B", bid: 42.50 }
]

bids = []
buyers.each do |buyer|
  # Create fictional distribution
  distribution = Distribution.where(name: buyer[:name], account: lead.account).first_or_create! do |d|
    d.endpoint_url = "https://example.com/#{buyer[:name].parameterize}/api"
    d.integration_type = "api"
    d.request_method = "post"
    d.request_format = "json"
    d.status = "active"
  end
  
  # Create bid
  bid = Bid.create!(
    bid_request: bid_request,
    distribution: distribution,
    amount: buyer[:bid],
    account: lead.account,
    status: :pending
  )
  
  bids << bid
  
  # Record bid received
  lead_activity_service.record_bid_received(lead, bid, {
    distribution_name: distribution.name,
    distribution_type: distribution.integration_type
  })
end

# 9. Record winning bid
winning_bid = bids.max_by(&:amount)
winning_bid.update(status: :accepted)

lead_activity_service.record_bid_selected(lead, winning_bid, {
  selection_method: "highest_bid",
  total_bids: bids.count,
  bid_request_id: bid_request.id
})

# 10. Record consent requested
winning_distribution = winning_bid.distribution
lead_activity_service.record_consent_requested(lead, winning_distribution, {
  consent_type: "distribution_consent",
  buyer_name: winning_distribution.name,
  buyer_type: winning_distribution.integration_type,
  consent_message: "Do you agree to share your information with #{winning_distribution.name}?"
})

# 11. Record consent provided
consent_record = ConsentRecord.create!(
  lead: lead,
  account: lead.account,
  consent_type: "distribution_consent", 
  consent_text: "I agree to share my information with #{winning_distribution.name}",
  ip_address: "127.0.0.1",
  user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
  status: :active
)

lead_activity_service.record_consent_provided(lead, consent_record, {
  buyer_name: winning_distribution.name,
  buyer_type: winning_distribution.integration_type,
  consent_timestamp: consent_record.created_at
})

# 12. Record distribution
api_request = ApiRequest.create!(
  requestable: winning_distribution,
  lead: lead,
  account: lead.account,
  endpoint_url: winning_distribution.endpoint_url,
  request_method: "post",
  request_payload: { lead_data: "sample data" }.to_json,
  response_code: 200,
  response_data: { success: true, lead_id: "BUYER-12345" }.to_json,
  duration_ms: 350,
  sent_at: Time.current
)

lead_activity_service.record_distribution(lead, api_request, {
  distribution_id: winning_distribution.id,
  distribution_name: winning_distribution.name,
  distribution_type: winning_distribution.integration_type,
  endpoint_url: winning_distribution.endpoint_url,
  request_method: "post",
  response_code: 200
})

# 13. Record buyer response
lead_activity_service.record_buyer_response(lead, api_request, {
  distribution_id: winning_distribution.id,
  distribution_name: winning_distribution.name,
  response_status: "accepted",
  response_time: 0.35,
  response_data: { success: true, lead_id: "BUYER-12345" }
})

# 14. Record status update - to distributed
lead_activity_service.record_status_update(lead, "processing", "distributed", {
  reason: "Successfully distributed to buyer",
  distribution_id: winning_distribution.id,
  distribution_name: winning_distribution.name
})

# 15. Record data access by admin
lead_activity_service.record_data_access(lead, user, {
  access_type: "view",
  fields_accessed: "all",
  reason: "Administrative review"
})

puts "Created #{lead.lead_activity_logs.count} activity records for lead #{lead.id}"