# frozen_string_literal: true

# This seed file creates compliance records for various activities in the system
# It creates records for leads, consent events, validation events, and distribution events
#
# To run this seed file individually:
# rails runner db/seeds/compliance_records.rb

puts "Creating compliance records..."

# Helper method to generate random IP and user agent
def random_ip
  [
    rand(1..255),
    rand(0..255),
    rand(0..255),
    rand(0..255)
  ].join(".")
end

def random_user_agent
  user_agents = [
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1"
  ]
  user_agents.sample
end

# Get the admin user for the compliance records
admin_user = User.find_by(email: "admin@example.com")
admin_user ||= User.first

# Create compliance records for each account
Account.find_each do |account|
  puts "Creating compliance records for account: #{account.name}"
  
  ActsAsTenant.with_tenant(account) do
    # Create compliance records for campaigns (assuming Campaign model exists)
    campaigns = Campaign.all.to_a
    
    if campaigns.any?
      campaigns.each do |campaign|
        # Record campaign creation
        ComplianceRecord.create(
          record: campaign,
          account: account,
          action: "CREATED",
          event_type: "CAMPAIGN_MANAGEMENT",
          data: {
            campaign_name: campaign.name,
            campaign_type: campaign.campaign_type,
            created_by: admin_user.email
          },
          user: admin_user,
          ip_address: random_ip,
          user_agent: random_user_agent,
          occurred_at: rand(1..30).days.ago
        )
        
        # Record campaign update (for some campaigns)
        if rand < 0.7 # 70% chance
          ComplianceRecord.create(
            record: campaign,
            account: account,
            action: "UPDATED",
            event_type: "CAMPAIGN_MANAGEMENT",
            data: {
              campaign_name: campaign.name,
              campaign_type: campaign.campaign_type,
              updated_fields: ["name", "description"].sample(rand(1..2)),
              updated_by: admin_user.email
            },
            user: admin_user,
            ip_address: random_ip,
            user_agent: random_user_agent,
            occurred_at: rand(1..15).days.ago
          )
        end
      end
    end
    
    # Create compliance records for validation rules
    validation_rules = ValidationRule.all.to_a
    
    if validation_rules.any?
      validation_rules.each do |rule|
        # Record validation rule creation
        ComplianceRecord.create(
          record: rule,
          account: account,
          action: "CREATED",
          event_type: "VALIDATION_MANAGEMENT",
          data: {
            rule_name: rule.name,
            rule_type: rule.rule_type,
            created_by: admin_user.email
          },
          user: admin_user,
          ip_address: random_ip,
          user_agent: random_user_agent,
          occurred_at: rand(1..30).days.ago
        )
        
        # Record validation execution events (multiple)
        rand(3..10).times do
          validation_result = [true, false].sample
          ComplianceRecord.create(
            record: rule,
            account: account,
            action: validation_result ? "VALIDATION_PASSED" : "VALIDATION_FAILED",
            event_type: "LEAD_VALIDATION",
            data: {
              rule_name: rule.name,
              rule_type: rule.rule_type,
              validation_result: validation_result,
              lead_id: rand(1000..9999), # Mock lead ID
              lead_field_value: ["test@example.com", "555-123-4567", "John Doe"].sample,
              error_message: validation_result ? nil : "Field value did not pass validation criteria"
            },
            user: nil, # System-generated event
            ip_address: random_ip,
            user_agent: random_user_agent,
            occurred_at: rand(1..10).days.ago
          )
        end
      end
    end
    
    # Create compliance records for account itself
    # Record account settings update
    ComplianceRecord.create(
      record: account,
      account: account,
      action: "SETTINGS_UPDATED",
      event_type: "ACCOUNT_MANAGEMENT",
      data: {
        updated_settings: ["compliance_settings", "notification_preferences", "integration_settings"].sample(rand(1..3)),
        updated_by: admin_user.email
      },
      user: admin_user,
      ip_address: random_ip,
      user_agent: random_user_agent,
      occurred_at: rand(1..20).days.ago
    )
    
    # Record account access events
    ["LOGIN", "LOGOUT", "PASSWORD_RESET", "2FA_ENABLED"].sample(rand(2..4)).each do |action|
      ComplianceRecord.create(
        record: admin_user,
        account: account,
        action: action,
        event_type: "SECURITY",
        data: {
          user_email: admin_user.email,
          success: true,
          device: ["desktop", "mobile", "tablet"].sample
        },
        user: admin_user,
        ip_address: random_ip,
        user_agent: random_user_agent,
        occurred_at: rand(1..15).days.ago
      )
    end
    
    # Create consent management records
    consent_types = ["MARKETING", "DATA_PROCESSING", "THIRD_PARTY_SHARING", "TCPA_CONSENT"]
    rand(5..15).times do
      consent_type = consent_types.sample
      consent_given = [true, false].sample
      
      ComplianceRecord.create(
        record: account, # Using account as the record since we don't have actual consent records
        account: account,
        action: consent_given ? "CONSENT_GIVEN" : "CONSENT_DECLINED",
        event_type: "CONSENT_MANAGEMENT",
        data: {
          consent_type: consent_type,
          lead_id: rand(1000..9999), # Mock lead ID
          lead_email: "lead#{rand(100..999)}@example.com",
          consent_text: "I agree to receive communications and allow my data to be processed according to the privacy policy.",
          capture_method: ["web_form", "checkbox", "api", "phone_call"].sample,
          ip_address: random_ip
        },
        user: nil, # System-generated event
        ip_address: random_ip,
        user_agent: random_user_agent,
        occurred_at: rand(1..30).days.ago
      )
    end
    
    # Create data access records
    rand(5..12).times do
      ComplianceRecord.create(
        record: account,
        account: account,
        action: ["DATA_EXPORTED", "DATA_ACCESSED", "REPORT_GENERATED"].sample,
        event_type: "DATA_ACCESS",
        data: {
          data_type: ["leads", "campaigns", "reports", "user_data"].sample,
          access_reason: ["compliance_audit", "data_analysis", "customer_request"].sample,
          records_accessed: rand(1..100),
          access_method: ["ui", "api", "export"].sample
        },
        user: admin_user,
        ip_address: random_ip,
        user_agent: random_user_agent,
        occurred_at: rand(1..25).days.ago
      )
    end
  end
end

puts "Finished creating compliance records!"