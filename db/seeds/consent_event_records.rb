# frozen_string_literal: true

# This seed file creates compliance records for all consent event types
# It creates records for consent given, rejected, and revoked events
# for each consent type.
#
# To run this seed file individually:
# rails runner db/seeds/consent_event_records.rb

require 'ostruct'

puts "Creating consent event records..."

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

# Generate random date between a range
def random_date(from, to)
  Time.at(rand(from.to_time.to_i..to.to_time.to_i))
end

# Generate a valid proof token
def generate_proof_token
  SecureRandom.hex(16)
end

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

# Get the admin user for the records
admin_user = User.find_by(email: "admin@example.com")
admin_user ||= User.first

# Set Current attributes for the run
Current.ip_address = random_ip
Current.user_agent = random_user_agent

# Define all consent types
CONSENT_TYPES = [
  "DISTRIBUTION_CONSENT",
  "MARKETING_CONSENT", 
  "TERMS_OF_SERVICE", 
  "PRIVACY_POLICY", 
  "DATA_SHARING",
  "MARKETING",
  "DATA_PROCESSING",
  "THIRD_PARTY_SHARING",
  "TCPA_CONSENT"
]

# Define all consent actions
CONSENT_ACTIONS = [
  "CONSENT_GIVEN",
  "CONSENT_REJECTED",
  "CONSENT_REVOKED"
]

# Consent text templates
CONSENT_TEXT_TEMPLATES = {
  "DISTRIBUTION_CONSENT" => "I agree to have my information shared with [COMPANY] and its partners for the purpose of receiving information about the requested services.",
  "MARKETING_CONSENT" => "I consent to receive marketing communications from [COMPANY] about their products and services.",
  "TERMS_OF_SERVICE" => "I have read and agree to the Terms of Service at [URL], which govern my use of [COMPANY]'s services.",
  "PRIVACY_POLICY" => "I have read and agree to the Privacy Policy at [URL], which describes how [COMPANY] collects, uses, and shares my personal information.",
  "DATA_SHARING" => "I consent to [COMPANY] sharing my information with third parties for the purpose of [PURPOSE].",
  "MARKETING" => "I agree to receive marketing materials from [COMPANY] via email, SMS, and other channels.",
  "DATA_PROCESSING" => "I consent to [COMPANY] processing my personal data for the purposes described in their privacy policy.",
  "THIRD_PARTY_SHARING" => "I consent to [COMPANY] sharing my information with third parties who may contact me about their products and services.",
  "TCPA_CONSENT" => "I expressly consent to receive phone calls and text messages from [COMPANY] and its partners, including through automated technology, at the phone number provided."
}

# Create consent records for each account
Account.find_each do |account|
  puts "Creating consent event records for account: #{account.name}"
  
  ActsAsTenant.with_tenant(account) do
    # Find leads or create mock leads
    leads = defined?(Lead) ? Lead.all.to_a : []
    
    if leads.empty?
      puts "No leads found for account: #{account.name}. Creating mock consent event records..."
      
      # Create mock compliance records for each consent type and action
      CONSENT_TYPES.each do |consent_type|
        CONSENT_ACTIONS.each do |action|
          # Generate random dates for each action type
          occurred_date = case action
            when "CONSENT_GIVEN"
              random_date(60.days.ago, 30.days.ago)
            when "CONSENT_REJECTED"
              random_date(30.days.ago, 15.days.ago)
            when "CONSENT_REVOKED"
              random_date(15.days.ago, 1.day.ago)
          end
          
          # Get text template for this consent type
          consent_text = CONSENT_TEXT_TEMPLATES[consent_type] || "I consent to [COMPANY] using my data for #{consent_type.downcase.humanize} purposes."
          consent_text = consent_text.gsub("[COMPANY]", account.name)
                                    .gsub("[URL]", "https://www.example.com/terms")
                                    .gsub("[PURPOSE]", "providing relevant services")
          
          # Update Current attributes
          ip = random_ip
          ua = random_user_agent
          Current.ip_address = ip
          Current.user_agent = ua
          
          # Create compliance record directly
          record = ComplianceRecord.create!(
            account: account,
            record: account, # Using account as record since we don't have a lead
            event_type: "consent",
            action: action.downcase,
            data: {
              consent_type: consent_type,
              consent_text: consent_text,
              source: ["web_form", "api", "mobile_app", "call_center"].sample,
              capture_method: ["checkbox", "signature", "verbal", "double_opt_in"].sample,
              platform: ["web", "mobile", "in-person", "phone"].sample
            },
            user: [admin_user, nil].sample, # Sometimes with user, sometimes system
            ip_address: ip,
            user_agent: ua,
            occurred_at: occurred_date
          )
          
          puts "  Created #{action.downcase} record for #{consent_type}"
        end
      end
    else
      puts "Creating consent event records for #{leads.count} leads..."
      
      # Create a set of consent records for the first 10 leads (or all if less than 10)
      sample_leads = leads.first(10)
      
      sample_leads.each do |lead|
        # Create one record for each consent type for this lead
        CONSENT_TYPES.each do |consent_type|
          # Decide which actions to create for this consent type (at least CONSENT_GIVEN)
          actions_to_create = ["CONSENT_GIVEN"]
          
          # 30% chance to add CONSENT_REJECTED
          if rand < 0.3
            actions_to_create << "CONSENT_REJECTED"
          end
          
          # 20% chance to add CONSENT_REVOKED if CONSENT_GIVEN exists
          if rand < 0.2
            actions_to_create << "CONSENT_REVOKED"
          end
          
          # Get text template for this consent type
          consent_text = CONSENT_TEXT_TEMPLATES[consent_type] || "I consent to [COMPANY] using my data for #{consent_type.downcase.humanize} purposes."
          consent_text = consent_text.gsub("[COMPANY]", account.name)
                                    .gsub("[URL]", "https://www.example.com/terms")
                                    .gsub("[PURPOSE]", "providing relevant services")
          
          # Create a consent record first if needed
          if actions_to_create.include?("CONSENT_GIVEN") || actions_to_create.include?("CONSENT_REVOKED")
            # Update Current attributes for this record
            ip = random_ip
            ua = random_user_agent
            Current.ip_address = ip
            Current.user_agent = ua
            
            # Create a ConsentRecord
            consent_record = ConsentRecord.create!(
              account: account,
              lead: lead,
              user_id: [admin_user.id, nil].sample(1).first, # Sometimes null
              consent_type: consent_type,
              consent_text: consent_text,
              ip_address: ip,
              user_agent: ua,
              consented_at: random_date(60.days.ago, 15.days.ago),
              expires_at: rand < 0.3 ? random_date(10.days.from_now, 365.days.from_now) : nil,
              proof_token: generate_proof_token,
              uuid: SecureRandom.uuid,
              metadata: {
                source: ["web_form", "api", "mobile_app", "call_center"].sample,
                campaign_id: lead.respond_to?(:campaign_id) ? lead.campaign_id : rand(1000..9999),
                form_id: "form_#{rand(100..999)}",
                capture_method: ["checkbox", "signature", "verbal", "double_opt_in"].sample
              },
              revoked: actions_to_create.include?("CONSENT_REVOKED"),
              revoked_at: actions_to_create.include?("CONSENT_REVOKED") ? random_date(14.days.ago, 1.day.ago) : nil,
              revocation_reason: actions_to_create.include?("CONSENT_REVOKED") ? ["user_request", "opt_out", "data_removal_request", "expired"].sample : nil
            )
            
            # Now create the compliance record for the consent given event
            if actions_to_create.include?("CONSENT_GIVEN")
              # Create compliance record for CONSENT_GIVEN
              ComplianceRecord.create!(
                account: account,
                record: consent_record,
                event_type: "consent",
                action: "consent_given",
                data: {
                  lead_id: lead.id,
                  consent_type: consent_type,
                  consent_text: consent_text.truncate(100),
                  capture_method: consent_record.metadata["capture_method"],
                  source: consent_record.metadata["source"]
                },
                user: consent_record.user,
                ip_address: consent_record.ip_address,
                user_agent: consent_record.user_agent,
                occurred_at: consent_record.consented_at
              )
              
              puts "  Created consent_given record for #{consent_type} for lead ##{lead.id}"
            end
            
            # Create the compliance record for consent revoked if needed
            if actions_to_create.include?("CONSENT_REVOKED") && consent_record.revoked?
              ComplianceRecord.create!(
                account: account,
                record: consent_record,
                event_type: "consent",
                action: "consent_revoked",
                data: {
                  lead_id: lead.id,
                  consent_type: consent_type,
                  revocation_reason: consent_record.revocation_reason,
                  original_consent_date: consent_record.consented_at.iso8601
                },
                user: [admin_user, nil].sample, # May be different from original consent user
                ip_address: random_ip,
                user_agent: random_user_agent,
                occurred_at: consent_record.revoked_at
              )
              
              puts "  Created consent_revoked record for #{consent_type} for lead ##{lead.id}"
            end
          end
          
          # Create just a compliance record for CONSENT_REJECTED if needed (no ConsentRecord)
          if actions_to_create.include?("CONSENT_REJECTED")
            ComplianceRecord.create!(
              account: account,
              record: lead,
              event_type: "consent",
              action: "consent_rejected",
              data: {
                consent_type: consent_type,
                rejection_reason: ["user_declined", "verification_failed", "abandoned_form", "timeout"].sample,
                attempted_at: random_date(60.days.ago, 1.day.ago).iso8601
              },
              user: nil, # System-generated
              ip_address: random_ip,
              user_agent: random_user_agent,
              occurred_at: random_date(30.days.ago, 1.day.ago)
            )
            
            puts "  Created consent_rejected record for #{consent_type} for lead ##{lead.id}"
          end
        end
      end
    end
  end
end

puts "Finished creating consent event records!"