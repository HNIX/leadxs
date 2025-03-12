# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).

# Uncomment the following to create an Admin user for Production in Jumpstart Pro
#
#   user = User.create(
#     name: "Admin User",
#     email: "email@example.org",
#     password: "password",
#     password_confirmation: "password",
#     terms_of_service: true
#   )
#   Jumpstart.grant_system_admin!(user)

# Create seed data for development
if Rails.env.development?
  puts "Creating development seed data..."
  
  # Create a test user if none exists
  unless User.exists?(email: "test@example.com")
    user = User.create!(
      name: "Test User",
      email: "test@example.com",
      password: "password",
      password_confirmation: "password",
      terms_of_service: true
    )
    puts "Created test user: #{user.email}"
  else
    user = User.find_by(email: "test@example.com")
    puts "Test user already exists: #{user.email}"
  end
  
  # Create a test account if none exists
  unless Account.exists?(name: "Test Account")
    account = Account.create!(
      name: "Test Account",
      owner: user
    )
    puts "Created test account: #{account.name}"
  else
    account = Account.find_by(name: "Test Account")
    puts "Test account already exists: #{account.name}"
  end
  
  # Add user to account if not already added
  unless AccountUser.exists?(user: user, account: account)
    AccountUser.create!(
      user: user,
      account: account,
      roles: {"admin" => true}
    )
    puts "Added test user to test account as admin"
  end
  
  # Create base verticals for the test account
  base_verticals = [
    {
      name: "Auto Insurance",
      primary_category: "Insurance",
      secondary_category: "Auto",
      description: "Lead generation for auto insurance quotes",
      base: true,
      account_id: account.id
    },
    {
      name: "Home Insurance",
      primary_category: "Insurance",
      secondary_category: "Home",
      description: "Lead generation for home insurance quotes",
      base: true,
      account_id: account.id
    },
    {
      name: "Life Insurance",
      primary_category: "Insurance",
      secondary_category: "Life",
      description: "Lead generation for life insurance quotes",
      base: true,
      account_id: account.id
    },
    {
      name: "Home Remodeling",
      primary_category: "Home Services",
      secondary_category: "Remodeling",
      description: "Lead generation for home remodeling contractors",
      base: true,
      account_id: account.id
    },
    {
      name: "Roofing",
      primary_category: "Home Services",
      secondary_category: "Roofing",
      description: "Lead generation for roofing services",
      base: true,
      account_id: account.id
    },
    {
      name: "HVAC",
      primary_category: "Home Services",
      secondary_category: "HVAC",
      description: "Lead generation for heating, ventilation, and air conditioning services",
      base: true,
      account_id: account.id
    },
    {
      name: "Solar Installation",
      primary_category: "Energy",
      secondary_category: "Solar",
      description: "Lead generation for residential solar panel installation",
      base: true,
      account_id: account.id
    },
    {
      name: "Mortgage Refinance",
      primary_category: "Finance",
      secondary_category: "Mortgage",
      description: "Lead generation for mortgage refinancing",
      base: true,
      account_id: account.id
    },
    {
      name: "Personal Loans",
      primary_category: "Finance",
      secondary_category: "Loans",
      description: "Lead generation for personal loans",
      base: true,
      account_id: account.id
    },
    {
      name: "Education Programs",
      primary_category: "Education",
      secondary_category: "Online Courses",
      description: "Lead generation for online education programs",
      base: true,
      account_id: account.id
    }
  ]
  
  # Temporarily disable the ActsAsTenant so we can create verticals directly
  ActsAsTenant.with_tenant(account) do
    base_verticals.each do |vertical_data|
      unless Vertical.exists?(name: vertical_data[:name], account_id: account.id)
        vertical = Vertical.create!(vertical_data)
        puts "Created base vertical: #{vertical.name}"
      else
        puts "Base vertical already exists: #{vertical_data[:name]}"
      end
    end
    
    # Create some custom verticals for the test account
    custom_verticals = [
      {
        name: "Custom Fitness Training",
        primary_category: "Healthcare",
        secondary_category: "Fitness",
        description: "Lead generation for personal fitness trainers",
        base: false,
        account_id: account.id
      },
      {
        name: "Custom Real Estate Buyers",
        primary_category: "Real Estate",
        secondary_category: "Home Buying",
        description: "Lead generation for potential home buyers",
        base: false,
        account_id: account.id
      }
    ]
    
    custom_verticals.each do |vertical_data|
      unless Vertical.exists?(name: vertical_data[:name], account_id: account.id)
        vertical = Vertical.create!(vertical_data)
        puts "Created custom vertical: #{vertical.name}"
      else
        puts "Custom vertical already exists: #{vertical_data[:name]}"
      end
    end
  end
  
  # Create standard fields for the account
  require_relative "seeds/standard_fields_setup"
  
  # Create vertical fields based on the standard fields
  require_relative "seeds/standard_vertical_fields"
  
  ActsAsTenant.with_tenant(account) do
    Vertical.all.each do |vertical|
      Seeds::StandardVerticalFields.create_standard_fields(vertical)
      puts "Created standard fields for vertical: #{vertical.name}"
    end
  end
  
  # Create some companies
  ActsAsTenant.with_tenant(account) do
    # Create a source company
    unless Company.exists?(name: "Publisher Company", account_id: account.id)
      company = Company.create!(
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
    end
    
    # Create a distribution company
    unless Company.exists?(name: "Buyer Company", account_id: account.id)
      company = Company.create!(
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
    end
  end
  
  # Create sample campaigns
  ActsAsTenant.with_tenant(account) do
    # Create campaigns for each vertical
    Vertical.all.each do |vertical|
      # Create a ping-post campaign
      unless Campaign.exists?(name: "#{vertical.name} Ping-Post Campaign", account_id: account.id)
        campaign = account.campaigns.create!(
          name: "#{vertical.name} Ping-Post Campaign",
          vertical: vertical,
          status: "active",
          campaign_type: "ping_post",
          description: "This campaign handles ping-post leads for #{vertical.name}",
          distribution_method: "highest_bid",
          distribution_schedule_enabled: true,
          distribution_schedule_days: ["monday", "tuesday", "wednesday", "thursday", "friday"],
          distribution_schedule_start_time: "08:00",
          distribution_schedule_end_time: "17:00"
        )
        puts "Created ping-post campaign for #{vertical.name}"
      end
      
      # Create a direct campaign
      unless Campaign.exists?(name: "#{vertical.name} Direct Campaign", account_id: account.id)
        campaign = account.campaigns.create!(
          name: "#{vertical.name} Direct Campaign",
          vertical: vertical,
          status: "draft",
          campaign_type: "direct",
          description: "This campaign handles direct leads for #{vertical.name}",
          distribution_method: "round_robin",
          distribution_schedule_enabled: false
        )
        puts "Created direct campaign for #{vertical.name}"
      end
      
      # Create a calls campaign
      unless Campaign.exists?(name: "#{vertical.name} Calls Campaign", account_id: account.id)
        campaign = account.campaigns.create!(
          name: "#{vertical.name} Calls Campaign",
          vertical: vertical,
          status: "paused",
          campaign_type: "calls",
          description: "This campaign handles call transfers for #{vertical.name}",
          distribution_method: "waterfall",
          distribution_schedule_enabled: true,
          distribution_schedule_days: ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday"],
          distribution_schedule_start_time: "09:00",
          distribution_schedule_end_time: "19:00"
        )
        puts "Created calls campaign for #{vertical.name}"
      end
    end
  end

  # Create leads and API requests
  require_relative "seeds/add_leads_and_api_requests"
  
  # Setup bidding system with distributions, campaign configurations, and test bids
  require_relative "seeds/bidding/setup_bidding_system"
  Seeds::Bidding::SetupBiddingSystem.setup
  
  # Create consent records
  require_relative "seeds/consent_records"
  
  # Create consent event records with all consent types
  require_relative "seeds/consent_event_records"
  
  # Create compliance records
  require_relative "seeds/compliance_records"
  
  # Create lead activity logs
  require_relative "seeds/lead_activity_logs"
  
  # Create test lead with complete activity timeline
  require_relative "seeds/test_lead_activities"
  
  puts "Development seed data created successfully!"
end
