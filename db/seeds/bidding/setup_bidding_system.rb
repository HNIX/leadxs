# This file sets up the bidding system with distributions, campaign distributions, and test bids
# It gets called from the main seeds.rb file

module Seeds
  module Bidding
    class SetupBiddingSystem
      def self.setup
        # Find the first admin account
        admin_user = User.joins(:account_users).where(account_users: { roles: { admin: true } }).first
        
        if admin_user.nil?
          puts "No admin user found. Creating a default admin..."
          admin_user = create_admin_user
        end
        
        # Get the admin's primary account
        admin_account = admin_user.accounts.first
        
        if admin_account.nil?
          puts "No account found for admin. Creating a default account..."
          admin_account = create_admin_account(admin_user)
        end
        
        puts "Using admin account: #{admin_account.name} (ID: #{admin_account.id})"
        
        ActsAsTenant.with_tenant(admin_account) do
          setup_verticals(admin_account)
          setup_companies(admin_account)
          create_distributions(admin_account)
          setup_campaigns(admin_account)
          configure_ping_post_campaigns(admin_account)
          create_test_bid_requests(admin_account)
          generate_analytics(admin_account)
        end
      end
      
      def self.create_admin_user
        user = User.create!(
          name: "Admin User",
          email: "admin@example.com",
          password: "password",
          password_confirmation: "password",
          terms_of_service: true
        )
        puts "Created admin user: #{user.email}"
        user
      end
      
      def self.create_admin_account(user)
        account = Account.create!(
          name: "Admin Account",
          owner: user
        )
        
        # Add user to account as admin
        AccountUser.create!(
          user: user,
          account: account,
          roles: { "admin" => true }
        )
        
        puts "Created admin account: #{account.name}"
        account
      end
      
      private
      
      def self.setup_verticals(account)
        require_relative "setup_complete_system"
        Seeds::Bidding::SetupCompleteSystem.setup_verticals(account)
      end
      
      def self.setup_campaigns(account)
        require_relative "setup_complete_system"
        Seeds::Bidding::SetupCompleteSystem.setup_campaigns(account)
      end
      
      def self.setup_companies(account)
        require_relative "setup_complete_system"
        Seeds::Bidding::SetupCompleteSystem.setup_companies(account)
      end
      
      def self.create_distributions(account)
        # Find or create a buyer company
        companies = Seeds::Bidding::SetupCompleteSystem.setup_companies(account)
        buyer_company = companies[:buyer]
        
        distribution_data = [
          {
            name: "High Bidder Distribution",
            endpoint_url: "https://example.com/api/high-bidder",
            request_method: "post",
            request_format: "json",
            status: "active",
            company: buyer_company,
            bidding_strategy: "dynamic",
            base_bid_amount: 15.50,
            min_bid_amount: 8.00,
            max_bid_amount: 25.00,
            account_id: account.id
          },
          {
            name: "Mid-Tier Distribution",
            endpoint_url: "https://example.com/api/mid-tier",
            request_method: "post",
            request_format: "json",
            status: "active",
            company: buyer_company,
            bidding_strategy: "rule_based",
            base_bid_amount: 10.25,
            min_bid_amount: 5.00,
            max_bid_amount: 15.00,
            account_id: account.id
          },
          {
            name: "Budget Distribution",
            endpoint_url: "https://example.com/api/budget",
            request_method: "post",
            request_format: "form",
            status: "active",
            company: buyer_company,
            bidding_strategy: "manual",
            base_bid_amount: 7.50,
            min_bid_amount: 5.00,
            max_bid_amount: 10.00,
            account_id: account.id
          },
          {
            name: "Premium Distribution",
            endpoint_url: "https://example.com/api/premium",
            request_method: "post",
            request_format: "json",
            status: "active",
            company: buyer_company,
            bidding_strategy: "dynamic",
            base_bid_amount: 18.75,
            min_bid_amount: 10.00,
            max_bid_amount: 30.00,
            account_id: account.id
          },
          {
            name: "Non-Bidding Distribution",
            endpoint_url: "https://example.com/api/non-bidding",
            request_method: "post",
            request_format: "json",
            status: "active",
            company: buyer_company,
            base_bid_amount: nil,
            account_id: account.id
          }
        ]
        
        distribution_data.each do |dist_data|
          unless Distribution.exists?(name: dist_data[:name], account_id: account.id)
            distribution = Distribution.create!(dist_data)
            puts "Created distribution: #{distribution.name}"
          else
            puts "Distribution already exists: #{dist_data[:name]}"
          end
        end
      end
      
      def self.configure_ping_post_campaigns(account)
        # Configure all ping-post campaigns with bidding settings
        Campaign.where(campaign_type: "ping_post", account_id: account.id).each do |campaign|
          # Set bid timeout seconds if not already set
          campaign.update(bid_timeout_seconds: rand(10..30)) unless campaign.bid_timeout_seconds
          
          # Add distributions to campaigns
          Seeds::Bidding::SetupCompleteSystem.add_distributions_to_campaigns(account)
          
          puts "Configured bidding for campaign: #{campaign.name}"
        end
      end
      
      # This method is no longer used - distributions are added in SetupCompleteSystem
      def self.add_distributions_to_campaign(campaign)
        # This method is kept for compatibility but functionality moved to SetupCompleteSystem
      end
      
      # This method is no longer used - campaign fields are added in SetupCompleteSystem
      def self.add_campaign_fields(campaign)
        # This method is kept for compatibility but functionality moved to SetupCompleteSystem
      end
      
      def self.create_test_bid_requests(account)
        # Create bid requests for ping-post campaigns
        ping_post_campaigns = Campaign.where(campaign_type: "ping_post", account_id: account.id)
        
        ping_post_campaigns.each do |campaign|
          # Create 15-30 bid requests for each campaign
          rand(15..30).times do
            create_bid_request_with_bids(campaign)
          end
          
          puts "Created test bid requests for campaign: #{campaign.name}"
        end
      end
      
      def self.create_bid_request_with_bids(campaign)
        # Create a random date within the last 30 days for each bid request
        created_at = rand(1..30).days.ago
        expires_at = created_at + campaign.bid_timeout_seconds.seconds
        
        # Generate anonymized data based on campaign fields
        anonymized_data = {}
        campaign.campaign_fields.where(ping_required: true).each do |field|
          anonymized_data[field.name] = generate_field_value(field)
        end
        
        # Create the bid request
        bid_request = BidRequest.create!(
          campaign: campaign,
          unique_id: SecureRandom.uuid,
          status: %w[completed expired].sample, # Either completed or expired for historical data
          anonymized_data: anonymized_data,
          expires_at: expires_at,
          created_at: created_at,
          updated_at: created_at + rand(1..campaign.bid_timeout_seconds).seconds,
          account_id: campaign.account_id
        )
        
        # Create bids for this request (from 1 to n distributions)
        distributions = campaign.distributions.where.not(base_bid_amount: nil).sample(rand(1..campaign.distributions.count))
        
        distributions.each do |distribution|
          bid_amount = calculate_bid_amount(distribution, anonymized_data)
          
          # Create the bid
          bid = Bid.create!(
            bid_request: bid_request,
            distribution: distribution,
            amount: bid_amount,
            status: (bid_request.status == 'completed' && distribution == distributions.first) ? 'accepted' : %w[rejected expired].sample,
            created_at: created_at + rand(1..campaign.bid_timeout_seconds / 2).seconds,
            updated_at: created_at + rand(1..campaign.bid_timeout_seconds).seconds,
            account_id: campaign.account_id
          )
        end
        
        # Create a lead for a percentage of the bid requests
        if rand < 0.7 # 70% of bid requests get a lead
          create_lead_for_bid_request(bid_request, anonymized_data)
        end
        
        bid_request
      end
      
      def self.generate_field_value(field)
        case field.data_type
        when "text"
          if field.value_acceptance == "list" && field.list_values.any?
            field.list_values.sample.list_value
          else
            case field.name
            when /name/i
              %w[John Jane Bob Alice Mike Sara Tom Susan].sample
            when /email/i
              "test#{rand(1000..9999)}@example.com"
            when /phone/i
              "555#{rand(1000000..9999999)}"
            when /address/i
              "#{rand(100..999)} Main St"
            when /city/i
              %w[Seattle Portland San_Francisco Los_Angeles New_York Chicago Miami].sample
            when /state/i
              %w[WA OR CA NY IL FL TX].sample
            when /zip/i
              rand(10000..99999).to_s
            else
              "Value #{rand(1..100)}"
            end
          end
        when "number"
          if field.value_acceptance == "range" && field.min_value.present? && field.max_value.present?
            rand(field.min_value..field.max_value)
          else
            rand(1..1000)
          end
        when "boolean"
          [true, false].sample
        when "date"
          (Date.today - rand(0..365).days).to_s
        else
          "Value #{rand(1..100)}"
        end
      end
      
      def self.calculate_bid_amount(distribution, anonymized_data)
        base_amount = distribution.base_bid_amount
        
        case distribution.bidding_strategy
        when "manual"
          base_amount
        when "rule_based"
          # Simple rule-based adjustments based on data
          multiplier = 1.0
          
          # Age-based rules
          if anonymized_data["age"].present? && anonymized_data["age"].to_i > 40
            multiplier *= 1.2
          end
          
          # Location-based rules
          if anonymized_data["state"].present? && %w[CA NY FL].include?(anonymized_data["state"])
            multiplier *= 1.3
          end
          
          # Credit score rules
          if anonymized_data["credit_score_range"].present? && anonymized_data["credit_score_range"].include?("Excellent")
            multiplier *= 1.5
          end
          
          # Apply multiplier with some randomness
          (base_amount * multiplier * rand(0.9..1.1)).round(2)
        when "dynamic"
          # More complex "dynamic" bidding with variable rates
          # We're just simulating this with more randomness
          (base_amount * rand(0.8..1.5)).round(2)
        else
          # Default with slight variation
          (base_amount * rand(0.95..1.05)).round(2)
        end
      end
      
      def self.create_lead_for_bid_request(bid_request, anonymized_data)
        campaign = bid_request.campaign
        winning_bid = bid_request.bids.where(status: 'accepted').first
        
        # Complete the lead data with post-required fields
        lead_data = anonymized_data.dup
        campaign.campaign_fields.where(post_required: true).each do |field|
          next if lead_data[field.name].present? # Skip if already in anonymized data
          lead_data[field.name] = generate_field_value(field)
        end
        
        # Get a random source for the campaign
        source = Source.where(account_id: campaign.account_id).first
        
        # If no source exists, create one
        unless source
          source = Source.create!(
            name: "Test Source",
            campaign: campaign,
            webhook_url: "https://example.com/webhook",
            status: "active",
            token: SecureRandom.hex(16),
            account_id: campaign.account_id
          )
        end
        
        # Add a lead with link to the bid request
        lead = Lead.create!(
          campaign: campaign,
          status: winning_bid ? 'distributed' : 'rejected',
          source: source,
          bid_request: bid_request,
          unique_id: SecureRandom.uuid,
          account_id: campaign.account_id,
          created_at: bid_request.created_at + campaign.bid_timeout_seconds.seconds + rand(1..10).seconds,
          updated_at: bid_request.created_at + campaign.bid_timeout_seconds.seconds + rand(1..10).seconds
        )
        
        # Update the bid request with the lead
        bid_request.update(lead: lead)
      end
      
      def self.generate_analytics(account)
        # Generate analytics for different time periods
        puts "Generating bid analytics snapshots..."
        
        # Daily snapshots for the last 30 days
        30.downto(1) do |days_ago|
          date = Date.current - days_ago.days
          GenerateBidAnalyticsJob.new.perform({
            period_type: :daily,
            for_date: date,
            account_id: account.id,
            all_campaigns: true,
            all_distributions: true
          })
          
          puts "Generated daily snapshot for #{date.strftime('%Y-%m-%d')}" if days_ago % 5 == 0
        end
        
        # Weekly snapshots for the last 8 weeks
        4.downto(1) do |weeks_ago|
          date = Date.current - (weeks_ago * 7).days
          GenerateBidAnalyticsJob.new.perform({
            period_type: :weekly,
            for_date: date,
            account_id: account.id,
            all_campaigns: true,
            all_distributions: true
          })
          
          puts "Generated weekly snapshot for week #{date.strftime('%W')}"
        end
        
        # Monthly snapshots for the last 3 months
        3.downto(1) do |months_ago|
          date = Date.current - months_ago.months
          GenerateBidAnalyticsJob.new.perform({
            period_type: :monthly,
            for_date: date,
            account_id: account.id,
            all_campaigns: true,
            all_distributions: true
          })
          
          puts "Generated monthly snapshot for #{date.strftime('%B %Y')}"
        end
        
        puts "Completed generating bid analytics snapshots"
      end
    end
  end
end