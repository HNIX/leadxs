# frozen_string_literal: true

# This seed file creates consent records for leads in the system
# It creates different types of consent records with various statuses
#
# To run this seed file individually:
# rails runner db/seeds/consent_records.rb

require 'ostruct'

puts "Creating consent records..."

# Helper methods
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
    "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (iPad; CPU OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (Linux; Android 11; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36"
  ]
  user_agents.sample
end

def random_uuid
  SecureRandom.uuid
end

def generate_proof_token
  # Generate a valid 32-character hexadecimal string
  SecureRandom.hex(16)
end

# Consent text templates
CONSENT_TEXT_TEMPLATES = {
  distribution_consent: [
    "I agree to have my information shared with [COMPANY] to contact me about their products and services.",
    "I expressly consent to receive phone calls and SMS messages from [COMPANY] and its partners about their products and services."
  ],
  marketing_consent: [
    "I consent to receive marketing communications from [COMPANY] about offers and promotions.",
    "I agree to receive emails, calls, and SMS messages about promotions and marketing offers."
  ],
  terms_of_service: [
    "I have read and agree to the Terms of Service, which can be viewed at [URL].",
    "I acknowledge that I have read and understand the Terms of Service, and I agree to be bound by them."
  ],
  privacy_policy: [
    "I have read and agree to the Privacy Policy, which outlines how my personal information will be collected, used, and shared.",
    "I consent to the collection and processing of my personal information as described in the Privacy Policy."
  ],
  data_sharing: [
    "I agree that my information may be shared with third-party partners for the purpose of [PURPOSE].",
    "I consent to the sharing of my information with partners who may have relevant offers or services."
  ]
}

# Mock Current request for seed data generation
module MockCurrentRequest
  def self.setup
    # Only proceed if we have the Current class available
    return unless defined?(Current)
    
    # Add a request method to Current that returns a mock object with ip and user_agent methods
    unless Current.respond_to?(:request)
      Current.singleton_class.define_method(:request) do
        OpenStruct.new(
          ip: Current.ip_address || "127.0.0.1",
          user_agent: Current.user_agent || "Seed Script"
        )
      end
    end
  end
end

# Apply the mock
MockCurrentRequest.setup

# Check if the ConsentRecord model exists
if defined?(ConsentRecord)
  # Find admin user for records
  admin_user = User.find_by(email: "admin@example.com")
  admin_user ||= User.first

  # Set up Current attributes for seed run
  Current.ip_address = random_ip
  Current.user_agent = random_user_agent

  # Create consent records for each account
  Account.find_each do |account|
    puts "Creating consent records for account: #{account.name}"
    
    ActsAsTenant.with_tenant(account) do
      # Find leads to attach consent records to
      leads = defined?(Lead) ? Lead.all.to_a : []
      
      if leads.empty?
        # No leads found, so we need to create temporary leads
        puts "No leads found for account: #{account.name}. Creating temporary leads for consent records..."
        
        # Check if we have the Lead model available
        if defined?(Lead)
          # Find a campaign to associate leads with
          campaign = Campaign.first
          
          if campaign
            # Create temporary leads
            temp_leads = []
            5.times do |i|
              # Create a temporary lead
              # Need to find a source for the lead
              source = Source.where(account: account).sample || 
                Source.create!(
                  name: "Seed Demo Source",
                  campaign: campaign,
                  company: Company.where(account: account).first,
                  account: account,
                  status: "active",
                  integration_type: "affiliate",
                  payout_method: "fixed",
                  payout: 5.0
                )
              
              lead = Lead.new(
                account: account,
                campaign: campaign,
                status: "new_lead",
                source: source,
                ip_address: random_ip,
                user_agent: random_user_agent,
                unique_id: SecureRandom.uuid
              )
              
              # Add any required attributes for Lead model
              lead.email = "temp_lead_#{i}@example.com" if lead.respond_to?(:email=)
              lead.first_name = "Temp#{i}" if lead.respond_to?(:first_name=)
              lead.last_name = "Lead#{i}" if lead.respond_to?(:last_name=)
              lead.phone = "555-#{rand(100..999)}-#{rand(1000..9999)}" if lead.respond_to?(:phone=)
              
              # Save the lead
              if lead.save
                temp_leads << lead
                puts "  Created temporary lead #{i+1}/5"
              else
                puts "  Failed to create temporary lead: #{lead.errors.full_messages.join(', ')}"
              end
            end
            
            # Create consent records for these temporary leads
            temp_leads.each do |lead|
              # For each lead, create 1-2 consent records
              rand(1..2).times do
                # Generate random consent type and text
                consent_type = ["DISTRIBUTION_CONSENT", "MARKETING_CONSENT", "TERMS_OF_SERVICE", "PRIVACY_POLICY", "DATA_SHARING"].sample
                base_text = CONSENT_TEXT_TEMPLATES[consent_type.downcase.to_sym].sample
                consent_text = base_text.gsub("[COMPANY]", account.name).gsub("[URL]", "https://www.example.com/terms").gsub("[PURPOSE]", "marketing purposes")
                
                # Update Current attributes for this record
                ip = random_ip
                ua = random_user_agent
                Current.ip_address = ip
                Current.user_agent = ua
                
                # Create consent record for the temporary lead
                ConsentRecord.create!(
                  account: account,
                  lead: lead,
                  user_id: [admin_user.id, nil].sample, # Sometimes record with user, sometimes not
                  consent_type: consent_type,
                  consent_text: consent_text,
                  ip_address: ip,
                  user_agent: ua,
                  consented_at: rand(1..60).days.ago,
                  expires_at: rand < 0.3 ? rand(1..365).days.from_now : nil, # 30% have expiration
                  proof_token: generate_proof_token,
                  uuid: random_uuid,
                  metadata: {
                    source: ["web_form", "api", "mobile_app", "call_center"].sample,
                    campaign_id: lead.campaign_id,
                    form_id: "form_#{rand(100..999)}",
                    capture_method: ["checkbox", "signature", "verbal", "double_opt_in"].sample
                  },
                  revoked: rand < 0.15, # 15% are revoked
                  revoked_at: rand < 0.15 ? rand(1..30).days.ago : nil,
                  revocation_reason: rand < 0.15 ? ["user_request", "opt_out", "data_removal_request", "expired"].sample : nil
                )
              end
            end
            
            puts "Created #{temp_leads.size} temporary leads with consent records"
          else
            puts "Skipping consent records - no campaigns found for account: #{account.name}"
          end
        else
          puts "Lead model not found. Skipping consent record creation."
        end
      else
        # Create consent records for actual leads
        puts "Creating consent records for #{leads.count} leads..."
        
        leads.each do |lead|
          # For each lead, create 1-3 consent records
          rand(1..3).times do
            # Generate random consent type and text
            consent_type = ["DISTRIBUTION_CONSENT", "MARKETING_CONSENT", "TERMS_OF_SERVICE", "PRIVACY_POLICY", "DATA_SHARING"].sample
            base_text = CONSENT_TEXT_TEMPLATES[consent_type.downcase.to_sym].sample
            consent_text = base_text.gsub("[COMPANY]", account.name).gsub("[URL]", "https://www.example.com/terms").gsub("[PURPOSE]", "marketing purposes")
            
            # Determine if this consent should be revoked
            is_revoked = rand < 0.15 # 15% chance of being revoked
            
            # Update Current attributes for this record
            ip = random_ip
            ua = random_user_agent
            Current.ip_address = ip
            Current.user_agent = ua
            
            # Create the consent record
            consent = ConsentRecord.create!(
              account: account,
              lead_id: lead.id,
              user_id: [admin_user.id, nil].sample(1).first, # Sometimes record with user
              consent_type: consent_type,
              consent_text: consent_text,
              ip_address: ip,
              user_agent: ua,
              consented_at: rand(1..60).days.ago,
              expires_at: rand < 0.3 ? rand(1..365).days.from_now : nil, # 30% have expiration
              proof_token: generate_proof_token,
              uuid: random_uuid,
              metadata: {
                source: ["web_form", "api", "mobile_app", "call_center"].sample,
                campaign_id: lead.respond_to?(:campaign_id) ? lead.campaign_id : rand(1000..9999),
                form_id: "form_#{rand(100..999)}",
                capture_method: ["checkbox", "signature", "verbal", "double_opt_in"].sample
              },
              revoked: is_revoked,
              revoked_at: is_revoked ? rand(1..30).days.ago : nil,
              revocation_reason: is_revoked ? ["user_request", "opt_out", "data_removal_request", "expired"].sample : nil
            )
            
            # Create compliance record for this consent if method exists
            if defined?(ComplianceRecord) && ComplianceRecord.respond_to?(:record_consent_event)
              # Check method signature to adapt our call
              method = ComplianceRecord.method(:record_consent_event)
              param_count = method.parameters.length
              
              if param_count >= 5  # If it expects a request parameter
                ComplianceRecord.record_consent_event(
                  consent,
                  is_revoked ? "CONSENT_REVOKED" : "CONSENT_GIVEN",
                  {
                    lead_id: lead.id,
                    consent_type: consent_type,
                    capture_method: consent.metadata["capture_method"],
                    expiration: consent.expires_at&.iso8601
                  },
                  admin_user,
                  Current.request
                )
              else  # If it doesn't expect a request parameter
                ComplianceRecord.record_consent_event(
                  consent,
                  is_revoked ? "CONSENT_REVOKED" : "CONSENT_GIVEN",
                  {
                    lead_id: lead.id,
                    consent_type: consent_type,
                    capture_method: consent.metadata["capture_method"],
                    expiration: consent.expires_at&.iso8601
                  }
                )
              end
            end
          end
        end
      end
      
      # Report on what we created
      consent_count = ConsentRecord.count
      active_count = ConsentRecord.where(revoked: false).count
      revoked_count = ConsentRecord.where(revoked: true).count
      
      puts "Created #{consent_count} consent records for account #{account.name}:"
      puts "- Active: #{active_count}"
      puts "- Revoked: #{revoked_count}"
    end
  end
  
  puts "Finished creating consent records!"
else
  puts "ConsentRecord model not found. Skipping consent record creation."
end