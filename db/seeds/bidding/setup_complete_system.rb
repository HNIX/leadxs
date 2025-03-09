# This file sets up a complete demo system with all components needed for bidding and lead management
# It creates verticals, fields, campaigns, sources, distributions, filters, validation rules, etc.

require_relative "setup_bidding_system"

module Seeds
  module Bidding
    class SetupCompleteSystem
      def self.setup_verticals(account)
        puts "Setting up verticals and fields..."
        
        # Create a few verticals if they don't exist
        verticals_data = [
          {
            name: "Auto Insurance",
            primary_category: "Insurance",
            secondary_category: "Auto",
            description: "Lead generation for auto insurance quotes",
            base: true
          },
          {
            name: "Home Insurance",
            primary_category: "Insurance",
            secondary_category: "Home",
            description: "Lead generation for home insurance quotes",
            base: true
          },
          {
            name: "Personal Loans",
            primary_category: "Finance",
            secondary_category: "Loans",
            description: "Lead generation for personal loans",
            base: true
          },
          {
            name: "Home Services",
            primary_category: "Home Services",
            secondary_category: "General",
            description: "Lead generation for home service providers",
            base: true
          }
        ]
        
        created_verticals = []
        
        verticals_data.each do |vertical_data|
          vertical = Vertical.find_by(name: vertical_data[:name], account_id: account.id)
          
          if vertical.nil?
            vertical = Vertical.create!(vertical_data.merge(account_id: account.id))
            puts "Created vertical: #{vertical.name}"
            created_verticals << vertical
          else
            puts "Vertical already exists: #{vertical.name}"
            created_verticals << vertical
          end
          
          # Add standard fields to the vertical if needed
          if vertical.vertical_fields.count == 0
            add_standard_fields_to_vertical(vertical)
            puts "Added standard fields to #{vertical.name}"
          end
        end
        
        created_verticals
      end
      
      def self.setup_companies(account)
        puts "Setting up companies..."
        
        # Create publisher company if doesn't exist
        publisher_company = Company.find_by(name: "Publisher Company", account_id: account.id)
        
        if publisher_company.nil?
          publisher_company = Company.create!(
            name: "Publisher Company",
            address: "123 Publisher St",
            city: "Seattle",
            state: "WA",
            zip_code: "98101",
            billing_cycle: "monthly",
            payment_terms: "net30",
            currency: "USD",
            account_id: account.id
          )
          puts "Created Publisher Company"
        else
          puts "Publisher Company already exists"
        end
        
        # Create buyer company if doesn't exist
        buyer_company = Company.find_by(name: "Buyer Company", account_id: account.id)
        
        if buyer_company.nil?
          buyer_company = Company.create!(
            name: "Buyer Company",
            address: "456 Buyer Ave",
            city: "San Francisco",
            state: "CA",
            zip_code: "94107",
            billing_cycle: "monthly",
            payment_terms: "net15",
            currency: "USD",
            account_id: account.id
          )
          puts "Created Buyer Company"
        else
          puts "Buyer Company already exists"
        end
        
        {publisher: publisher_company, buyer: buyer_company}
      end
      
      def self.setup_campaigns(account)
        puts "Setting up campaigns..."
        
        # Get all verticals
        verticals = Vertical.where(account_id: account.id)
        
        verticals.each do |vertical|
          # Create a ping-post campaign
          unless Campaign.exists?(name: "#{vertical.name} Ping-Post Campaign", account_id: account.id)
            campaign = account.campaigns.create!(
              name: "#{vertical.name} Ping-Post Campaign",
              vertical: vertical,
              status: "active",
              campaign_type: "ping_post",
              description: "This campaign handles ping-post leads for #{vertical.name}",
              distribution_method: "highest_bid",
              bid_timeout_seconds: rand(10..30),
              distribution_schedule_enabled: true,
              distribution_schedule_days: ["monday", "tuesday", "wednesday", "thursday", "friday"],
              distribution_schedule_start_time: "08:00",
              distribution_schedule_end_time: "17:00"
            )
            puts "Created ping-post campaign for #{vertical.name}"
            
            # Add campaign fields
            add_campaign_fields(campaign, vertical)
          end
          
          # Create a direct campaign
          unless Campaign.exists?(name: "#{vertical.name} Direct Campaign", account_id: account.id)
            campaign = account.campaigns.create!(
              name: "#{vertical.name} Direct Campaign",
              vertical: vertical,
              status: "active",
              campaign_type: "direct",
              description: "This campaign handles direct leads for #{vertical.name}",
              distribution_method: "round_robin",
              distribution_schedule_enabled: false
            )
            puts "Created direct campaign for #{vertical.name}"
            
            # Add campaign fields
            add_campaign_fields(campaign, vertical)
          end
        end
      end
      
      def self.add_campaign_fields(campaign, vertical)
        # Skip if campaign already has fields
        return if campaign.campaign_fields.count > 0
        
        # Map vertical fields to campaign fields
        vertical.vertical_fields.each do |vertical_field|
          campaign_field = campaign.campaign_fields.create!(
            name: vertical_field.name,
            label: vertical_field.label,
            data_type: vertical_field.data_type,
            required: vertical_field.required,
            ping_required: campaign.campaign_type == "ping_post" ? vertical_field.ping_required || false : false,
            post_required: campaign.campaign_type == "ping_post" ? vertical_field.post_required || false : vertical_field.required,
            is_pii: vertical_field.is_pii || false,
            value_acceptance: vertical_field.value_acceptance || "any",
            min_value: vertical_field.min_value,
            max_value: vertical_field.max_value,
            regex_validator: vertical_field.regex_validator,
            vertical_field: vertical_field,
            position: vertical_field.position,
            account_id: campaign.account_id
          )
          
          # Copy list values if applicable
          if vertical_field.value_acceptance == "list"
            vertical_field.list_values.each do |list_value|
              campaign_field.list_values.create!(
                list_value: list_value.list_value,
                value_type: list_value.value_type,
                position: list_value.position,
                account_id: campaign.account_id
              )
            end
          end
        end
        
        # Add validation rules
        add_validation_rules(campaign) if campaign.campaign_type == "ping_post"
        
        # Add sources
        add_sources(campaign)
        
        puts "Added #{vertical.vertical_fields.count} fields to campaign #{campaign.name}"
      end
      
      def self.add_sources(campaign)
        # Skip if campaign already has sources
        return if campaign.sources.count > 0
        
        # Create sources for the campaign
        source_names = ["API Source", "Web Form Source", "Partner Source"]
        
        source_names.each do |name|
          source = Source.create!(
            name: "#{campaign.name} - #{name}",
            campaign: campaign,
            webhook_url: "https://example.com/webhook",
            status: "active",
            token: SecureRandom.hex(16),
            account_id: campaign.account_id
          )
          
          puts "Created source: #{source.name}"
        end
      end
      
      def self.add_validation_rules(campaign)
        # Skip if campaign already has validation rules
        return if campaign.validation_rules.count > 0
        
        # Create common validation rules
        rules = []
        
        # Email validation
        email_field = campaign.campaign_fields.find_by(name: "email")
        if email_field
          rules << {
            name: "Valid Email Format",
            description: "Ensures email is in a valid format",
            rule_type: "regex",
            field_id: email_field.id,
            pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$",
            error_message: "Email must be in a valid format",
            active: true
          }
        end
        
        # Age validation if age field exists
        age_field = campaign.campaign_fields.find_by(name: "age")
        if age_field
          rules << {
            name: "Adult Age Verification",
            description: "Ensures lead is at least 18 years old",
            rule_type: "comparison",
            field_id: age_field.id,
            comparison_operator: ">=",
            comparison_value: "18",
            error_message: "Lead must be at least 18 years old",
            active: true
          }
        end
        
        # Phone validation
        phone_field = campaign.campaign_fields.find_by(name: /phone/i)
        if phone_field
          rules << {
            name: "Valid Phone Format",
            description: "Ensures phone number is in a valid format",
            rule_type: "regex",
            field_id: phone_field.id,
            pattern: "^[0-9]{10}$|^\\([0-9]{3}\\)[0-9]{3}-[0-9]{4}$",
            error_message: "Phone must be 10 digits or in (XXX)XXX-XXXX format",
            active: true
          }
        end
        
        # Create validation rules
        position = 0
        rules.each do |rule_data|
          position += 10
          rule = ValidationRule.create!(
            rule_data.merge(
              campaign: campaign,
              position: position,
              account_id: campaign.account_id
            )
          )
          puts "Created validation rule: #{rule.name} for campaign #{campaign.name}"
        end
      end
      
      def self.add_distributions_to_campaigns(account)
        puts "Adding distributions to campaigns..."
        
        # Get all ping-post campaigns
        ping_post_campaigns = Campaign.where(campaign_type: "ping_post", account_id: account.id)
        
        # Get all distributions
        distributions = Distribution.where(account_id: account.id)
        
        ping_post_campaigns.each do |campaign|
          distributions.each do |distribution|
            unless CampaignDistribution.exists?(campaign: campaign, distribution: distribution)
              campaign_distribution = CampaignDistribution.create!(
                campaign: campaign,
                distribution: distribution,
                active: true,
                priority: rand(1..10)
              )
              
              # Create field mappings
              create_field_mappings(campaign_distribution)
              
              puts "Added distribution #{distribution.name} to campaign #{campaign.name}"
            end
          end
        end
      end
      
      def self.create_field_mappings(campaign_distribution)
        # Get all campaign fields
        campaign_fields = campaign_distribution.campaign.campaign_fields
        
        # Map each campaign field to a target field
        campaign_fields.each do |campaign_field|
          # Check if a mapping already exists
          unless MappedField.exists?(campaign_distribution_id: campaign_distribution.id, campaign_field_id: campaign_field.id)
            MappedField.create!(
              campaign_distribution_id: campaign_distribution.id,
              campaign_field_id: campaign_field.id,
              distribution_field_name: "#{campaign_field.name.underscore}_#{campaign_field.id}"
            )
          end
        end
        
        puts "Created #{campaign_fields.count} field mappings for distribution"
      end
      
      def self.add_standard_fields_to_vertical(vertical)
        # Common fields for all verticals
        common_fields = [
          {
            name: "first_name",
            label: "First Name",
            data_type: "text",
            required: true,
            post_required: true,
            is_pii: true
          },
          {
            name: "last_name",
            label: "Last Name",
            data_type: "text",
            required: true,
            post_required: true,
            is_pii: true
          },
          {
            name: "email",
            label: "Email",
            data_type: "text",
            required: true,
            post_required: true,
            is_pii: true
          },
          {
            name: "phone",
            label: "Phone",
            data_type: "text",
            required: true,
            post_required: true,
            is_pii: true
          },
          {
            name: "address",
            label: "Address",
            data_type: "text",
            required: false,
            post_required: true,
            is_pii: true
          },
          {
            name: "city",
            label: "City",
            data_type: "text",
            required: true,
            ping_required: true,
            is_pii: false
          },
          {
            name: "state",
            label: "State",
            data_type: "text",
            required: true,
            ping_required: true,
            is_pii: false,
            value_acceptance: "list"
          },
          {
            name: "zip",
            label: "Zip Code",
            data_type: "text",
            required: true,
            ping_required: true,
            is_pii: false
          }
        ]
        
        # Add vertical-specific fields based on category
        if vertical.primary_category == "Insurance"
          if vertical.secondary_category == "Auto"
            auto_insurance_fields = [
              {
                name: "age",
                label: "Age",
                data_type: "number",
                required: true,
                ping_required: true,
                is_pii: false,
                value_acceptance: "range",
                min_value: 16,
                max_value: 100
              },
              {
                name: "gender",
                label: "Gender",
                data_type: "text",
                required: true,
                ping_required: true,
                is_pii: false,
                value_acceptance: "list"
              },
              {
                name: "vehicle_year",
                label: "Vehicle Year",
                data_type: "number",
                required: true,
                ping_required: true,
                is_pii: false,
                value_acceptance: "range",
                min_value: 1980,
                max_value: Time.current.year + 1
              },
              {
                name: "vehicle_make",
                label: "Vehicle Make",
                data_type: "text",
                required: true,
                ping_required: true,
                is_pii: false
              },
              {
                name: "vehicle_model",
                label: "Vehicle Model",
                data_type: "text",
                required: true,
                ping_required: true,
                is_pii: false
              }
            ]
            common_fields.concat(auto_insurance_fields)
          elsif vertical.secondary_category == "Home"
            home_insurance_fields = [
              {
                name: "property_type",
                label: "Property Type",
                data_type: "text",
                required: true,
                ping_required: true,
                is_pii: false,
                value_acceptance: "list"
              },
              {
                name: "year_built",
                label: "Year Built",
                data_type: "number",
                required: true,
                ping_required: true,
                is_pii: false,
                value_acceptance: "range",
                min_value: 1900,
                max_value: Time.current.year
              },
              {
                name: "home_value",
                label: "Home Value",
                data_type: "number",
                required: true,
                ping_required: true,
                is_pii: false
              }
            ]
            common_fields.concat(home_insurance_fields)
          end
        elsif vertical.primary_category == "Finance"
          finance_fields = [
            {
              name: "loan_amount",
              label: "Loan Amount",
              data_type: "number",
              required: true,
              ping_required: true,
              is_pii: false
            },
            {
              name: "credit_score",
              label: "Credit Score",
              data_type: "text",
              required: true,
              ping_required: true,
              is_pii: false,
              value_acceptance: "list"
            },
            {
              name: "loan_purpose",
              label: "Loan Purpose",
              data_type: "text",
              required: true,
              ping_required: true,
              is_pii: false,
              value_acceptance: "list"
            }
          ]
          common_fields.concat(finance_fields)
        elsif vertical.primary_category == "Home Services"
          home_services_fields = [
            {
              name: "service_type",
              label: "Service Type",
              data_type: "text",
              required: true,
              ping_required: true,
              is_pii: false,
              value_acceptance: "list"
            },
            {
              name: "timeframe",
              label: "Timeframe",
              data_type: "text",
              required: true,
              ping_required: true,
              is_pii: false,
              value_acceptance: "list"
            },
            {
              name: "budget",
              label: "Budget",
              data_type: "number",
              required: true,
              ping_required: true,
              is_pii: false,
              value_acceptance: "range",
              min_value: 100,
              max_value: 50000
            }
          ]
          common_fields.concat(home_services_fields)
        end
        
        # Create all fields
        position = 0
        common_fields.each do |field_data|
          position += 10
          
          # Handle list field specially
          if field_data[:value_acceptance] == "list"
            list_values_data = get_list_values_for_field_name(field_data[:name])
            
            # If no list values found, change to any acceptance
            if list_values_data.empty?
              field_data = field_data.merge(value_acceptance: "any")
              
              # Create the field
              field = vertical.vertical_fields.create!(
                field_data.merge(
                  position: position,
                  account_id: vertical.account_id
                )
              )
            else
              # For list fields, we need to include list values during creation
              field = vertical.vertical_fields.new(
                field_data.merge(
                  position: position,
                  account_id: vertical.account_id
                )
              )
              
              # Add list values before saving
              list_values_data.each_with_index do |list_value_data, index|
                field.list_values.build(
                  list_value: list_value_data[:list_value],
                  value_type: list_value_data[:value_type],
                  position: index + 1,
                  account_id: vertical.account_id
                )
              end
              
              # Now save with the list values
              field.save!
            end
          else
            # For non-list fields, just create normally
            field = vertical.vertical_fields.create!(
              field_data.merge(
                position: position,
                account_id: vertical.account_id
              )
            )
          end
        end
      end
      
      def self.get_list_values_for_field_name(field_name)
        # Return appropriate list values based on field name
        case field_name
        when "state"
          [
            { list_value: "AL", value_type: "string" },
            { list_value: "AK", value_type: "string" },
            { list_value: "AZ", value_type: "string" },
            { list_value: "AR", value_type: "string" },
            { list_value: "CA", value_type: "string" },
            { list_value: "CO", value_type: "string" },
            { list_value: "CT", value_type: "string" },
            { list_value: "DE", value_type: "string" },
            { list_value: "FL", value_type: "string" },
            { list_value: "GA", value_type: "string" },
            { list_value: "HI", value_type: "string" },
            { list_value: "ID", value_type: "string" },
            { list_value: "IL", value_type: "string" },
            { list_value: "IN", value_type: "string" },
            { list_value: "IA", value_type: "string" }
          ]
        when "gender"
          [
            { list_value: "Male", value_type: "string" },
            { list_value: "Female", value_type: "string" },
            { list_value: "Other", value_type: "string" }
          ]
        when "property_type"
          [
            { list_value: "Single Family Home", value_type: "string" },
            { list_value: "Condo", value_type: "string" },
            { list_value: "Townhouse", value_type: "string" },
            { list_value: "Multi-Family", value_type: "string" },
            { list_value: "Mobile Home", value_type: "string" }
          ]
        when "credit_score"
          [
            { list_value: "Excellent (720+)", value_type: "string" },
            { list_value: "Good (680-719)", value_type: "string" },
            { list_value: "Fair (640-679)", value_type: "string" },
            { list_value: "Poor (580-639)", value_type: "string" },
            { list_value: "Bad (below 580)", value_type: "string" }
          ]
        when "loan_purpose"
          [
            { list_value: "Debt Consolidation", value_type: "string" },
            { list_value: "Home Improvement", value_type: "string" },
            { list_value: "Major Purchase", value_type: "string" },
            { list_value: "Business", value_type: "string" },
            { list_value: "Other", value_type: "string" }
          ]
        when "service_type"
          [
            { list_value: "Plumbing", value_type: "string" },
            { list_value: "Electrical", value_type: "string" },
            { list_value: "HVAC", value_type: "string" },
            { list_value: "Roofing", value_type: "string" },
            { list_value: "Landscaping", value_type: "string" },
            { list_value: "Cleaning", value_type: "string" }
          ]
        when "timeframe"
          [
            { list_value: "Immediately", value_type: "string" },
            { list_value: "Within 1 week", value_type: "string" },
            { list_value: "Within 1 month", value_type: "string" },
            { list_value: "1-3 months", value_type: "string" },
            { list_value: "3+ months", value_type: "string" }
          ]
        else
          []
        end
      end
      
      # This method is no longer needed as list values are now created at the same time as the field
    end
  end
end