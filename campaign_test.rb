#!/usr/bin/env ruby

# This script tests creating a campaign from a vertical with standard fields
account = Account.first
puts "Using account: #{account.name}"

# Get the vertical we just created
vertical = account.verticals.find_by(name: "Test Vertical After Fix")
puts "Using vertical: #{vertical.name}"
puts "Vertical fields count: #{vertical.vertical_fields.count}"

# Create a campaign for this vertical with required fields
campaign = account.campaigns.create!(
  name: "Test Campaign", 
  vertical: vertical,
  status: "draft",
  campaign_type: "ping_post",
  distribution_method: "highest_bid",
  multi_distribution_strategy: "single",
  max_distributions: 1,
  bid_timeout_seconds: 10
)
puts "Created campaign: #{campaign.name}"

# Generate fields for the campaign
CampaignFieldGenerator.new(campaign).generate_fields!
puts "Campaign fields count: #{campaign.campaign_fields.count}"

puts "Campaign field details:"
campaign.campaign_fields.each do |field|
  puts "- #{field.name} (#{field.data_type})"
end

puts "Done!"