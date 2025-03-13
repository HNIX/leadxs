# Seeds for leads, lead data, and API requests
# This file creates sample data for testing the API requests and leads tracking interfaces

puts "Creating leads, lead data and API requests..."

# Make sure we have at least one account, campaign, and source to work with
account = Account.first || Account.create!(name: "Test Account", owner: User.first || User.create!(email: "admin@example.com", password: "password", password_confirmation: "password"))
campaign = Campaign.first || Campaign.create!(name: "Test Campaign", account: account, vertical: Vertical.first || Vertical.create!(name: "Test Vertical", account: account))
company = Company.first || Company.create!(name: "Test Company", account: account)
source = Source.find_by(name: "Test Source") || Source.create!(
  name: "Test Source",
  campaign: campaign,
  company: company,
  account: account,
  status: "active",
  integration_type: "web_form"
)

distribution = Distribution.find_by(name: "Test Distribution") || Distribution.create!(
  name: "Test Distribution",
  company: company,
  account: account,
  endpoint_url: "https://api.example.com/leads",
  request_method: "post",
  request_format: "json",
  authentication_token: "test_token"
)

# Make sure campaign has a connection to distribution
unless CampaignDistribution.exists?(campaign: campaign, distribution: distribution)
  CampaignDistribution.create!(
    campaign: campaign,
    distribution: distribution,
    active: true,
    priority: 1
  )
end

# Get or create required campaign fields
first_name_field = CampaignField.find_by(name: "first_name", campaign: campaign) || 
  CampaignField.create!(
    name: "first_name",
    campaign: campaign,
    account: account,
    field_type: "text",
    required: true,
    label: "First Name"
  )

last_name_field = CampaignField.find_by(name: "last_name", campaign: campaign) || 
  CampaignField.create!(
    name: "last_name",
    campaign: campaign,
    account: account,
    field_type: "text",
    required: true,
    label: "Last Name"
  )

email_field = CampaignField.find_by(name: "email", campaign: campaign) || 
  CampaignField.create!(
    name: "email",
    campaign: campaign,
    account: account,
    field_type: "email",
    required: true,
    label: "Email"
  )

phone_field = CampaignField.find_by(name: "phone", campaign: campaign) || 
  CampaignField.create!(
    name: "phone",
    campaign: campaign,
    account: account,
    field_type: "phone",
    required: true,
    label: "Phone"
  )

# Create test leads (10 successful, 5 failed) with lead data
15.times do |i|
  # Create a lead
  lead = Lead.create!(
    account: account,
    campaign: campaign,
    source: source,
    status: i < 10 ? :distributed : :error,
    ip_address: "192.168.1.#{i + 1}",
    user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36",
    referrer: "https://example.com/landing-page",
    first_distributed_at: i < 10 ? Time.current - rand(1..30).days : nil,
    distribution_count: i < 10 ? rand(1..3) : 0
  )
  
  # Create lead data
  LeadData.create!(
    lead: lead,
    campaign_field: first_name_field,
    value: ["John", "Jane", "Adam", "Emily", "Michael", "Sarah", "David", "Lisa"].sample
  )
  
  LeadData.create!(
    lead: lead,
    campaign_field: last_name_field,
    value: ["Smith", "Johnson", "Williams", "Jones", "Brown", "Miller", "Wilson"].sample
  )
  
  LeadData.create!(
    lead: lead,
    campaign_field: email_field,
    value: "test#{i+1}@example.com"
  )
  
  LeadData.create!(
    lead: lead,
    campaign_field: phone_field,
    value: "555-#{100 + i}-#{1000 + i}"
  )
  
  # Create API requests for this lead
  
  # Request to source (only for some leads)
  if i % 3 == 0
    ApiRequest.create!(
      requestable: source,
      lead: lead,
      account: account,
      endpoint_url: "https://source.example.com/api/leads",
      request_method: :post,
      request_payload: {
        lead_id: lead.id,
        first_name: lead.field_value(first_name_field.id),
        last_name: lead.field_value(last_name_field.id),
        email: lead.field_value(email_field.id),
        phone: lead.field_value(phone_field.id)
      }.to_json,
      response_code: i < 10 ? 200 : 400,
      response_payload: i < 10 ? 
        { status: "success", message: "Lead received" }.to_json : 
        { status: "error", message: "Invalid lead data" }.to_json,
      duration_ms: rand(50..1500),
      error: i < 10 ? nil : "Invalid lead data: Email already exists",
      sent_at: Time.current - rand(1..30).days
    )
  end
  
  # Request to distribution (for all leads)
  ApiRequest.create!(
    requestable: distribution,
    lead: lead,
    account: account,
    endpoint_url: "https://api.example.com/leads",
    request_method: :post,
    request_payload: {
      id: lead.id,
      first_name: lead.field_value(first_name_field.id),
      last_name: lead.field_value(last_name_field.id),
      email: lead.field_value(email_field.id),
      phone: lead.field_value(phone_field.id),
      campaign: campaign.name
    }.to_json,
    response_code: i < 10 ? 201 : (i < 12 ? 400 : 500),
    response_payload: i < 10 ? 
      { id: "ext-#{100000 + i}", status: "accepted", price: (rand(5..15) + rand).round(2) }.to_json : 
      { error: i < 12 ? "Validation failed" : "Server error" }.to_json,
    duration_ms: rand(50..1500),
    error: i < 10 ? nil : (i < 12 ? "Invalid data format" : "Internal server error"),
    sent_at: i < 10 ? Time.current - rand(1..30).days : nil
  )
  
  # Additional API requests for some leads to show multiple attempts
  if i < 10 && i % 2 == 0
    # Add a second successful request
    ApiRequest.create!(
      requestable: distribution,
      lead: lead,
      account: account,
      endpoint_url: "https://backup-api.example.com/leads",
      request_method: :post,
      request_payload: {
        id: lead.id,
        first_name: lead.field_value(first_name_field.id),
        last_name: lead.field_value(last_name_field.id),
        email: lead.field_value(email_field.id),
        phone: lead.field_value(phone_field.id),
        campaign: campaign.name
      }.to_json,
      response_code: 200,
      response_payload: { id: "ext2-#{200000 + i}", status: "accepted", price: (rand(3..10) + rand).round(2) }.to_json,
      duration_ms: rand(50..1500),
      sent_at: Time.current - rand(1..30).days
    )
  elsif i >= 10 && i % 2 == 1
    # Add a second failed request for some of the error leads
    ApiRequest.create!(
      requestable: distribution,
      lead: lead,
      account: account,
      endpoint_url: "https://backup-api.example.com/leads",
      request_method: :post,
      request_payload: {
        id: lead.id,
        first_name: lead.field_value(first_name_field.id),
        last_name: lead.field_value(last_name_field.id),
        email: lead.field_value(email_field.id),
        phone: lead.field_value(phone_field.id),
        campaign: campaign.name
      }.to_json,
      response_code: 503,
      response_payload: { error: "Service unavailable" }.to_json,
      duration_ms: rand(1500..5000),
      error: "Timeout waiting for response from server",
      sent_at: nil
    )
  end
end

# Create some API requests without leads (for testing)
5.times do |i|
  ApiRequest.create!(
    requestable: distribution,
    account: account,
    endpoint_url: "https://api.example.com/status",
    request_method: :get,
    request_payload: {}.to_json,
    response_code: i < 3 ? 200 : 503,
    response_payload: i < 3 ? 
      { status: "ok", server: "api-#{i}", uptime: rand(1000..100000) }.to_json : 
      { error: "Service unavailable" }.to_json,
    duration_ms: i < 3 ? rand(20..100) : rand(5000..10000),
    error: i < 3 ? nil : "Timeout waiting for response",
    sent_at: Time.current - rand(1..30).days
  )
end

puts "Created #{Lead.count} leads with #{LeadData.count} lead data records and #{ApiRequest.count} API requests."