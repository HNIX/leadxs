# This seeder adds sources to existing campaigns
# Run it with: bin/rails db:seed:add_sources

puts "Creating sources for campaigns..."

# Find all active campaigns
campaigns = Campaign.all

# Create sources for each campaign
campaigns.each_with_index do |campaign, index|
  # Get companies for the same account
  companies = Company.where(account_id: campaign.account_id)
  next if companies.empty?

  # Create affiliate source
  source1 = Source.create!(
    name: "#{campaign.name} Affiliate #{index + 1}",
    integration_type: "affiliate",
    status: "active",
    payout_method: "fixed",
    payout_structure: "per_lead",
    minimum_acceptable_bid: rand(1.0..10.0).round(2),
    margin: rand(0.5..3.0).round(2),
    payout: rand(5.0..20.0).round(2),
    daily_budget: rand(50.0..200.0).round(2),
    monthly_budget: rand(1000.0..5000.0).round(2),
    notes: "Affiliate source for #{campaign.name}. Created by seed script.",
    campaign: campaign,
    company: companies.sample,
    account_id: campaign.account_id
  )
  puts "  Created affiliate source: #{source1.name}"

  # Create web form source
  source2 = Source.create!(
    name: "#{campaign.name} Web Form #{index + 1}",
    integration_type: "web_form",
    status: "active",
    payout_method: "percentage",
    payout_structure: "per_conversion",
    minimum_acceptable_bid: rand(3.0..15.0).round(2),
    margin: rand(1.0..4.0).round(2),
    payout: rand(10.0..30.0).round(2),
    daily_budget: rand(75.0..300.0).round(2),
    monthly_budget: rand(2000.0..7000.0).round(2),
    notes: "Web form source for #{campaign.name}. Created by seed script.",
    campaign: campaign,
    company: companies.sample,
    account_id: campaign.account_id
  )
  puts "  Created web form source: #{source2.name}"
end

puts "Finished creating sources."