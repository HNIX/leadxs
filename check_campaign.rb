campaign = Campaign.first
puts "Campaign type: #{campaign.campaign_type}"
puts "Uses bidding system: #{campaign.use_bidding_system?}"

if campaign.campaign_type != 'ping_post'
  puts "FIXING: Updating campaign_type to ping_post"
  campaign.update(campaign_type: 'ping_post')
  puts "New campaign_type: #{campaign.campaign_type}"
  puts "Now uses bidding system: #{campaign.use_bidding_system?}"
end

# Now check if distributions are eligible
lead = Lead.last
lead_data = lead.field_values_hash
eligible = campaign.eligible_distributions_for_bidding(lead_data)
puts "After fixing campaign type:"
puts "Eligible distributions: #{eligible.count}"
puts "Eligible IDs: #{eligible.map(&:id).join(', ')}"

# Create a test bid request
bid_service = BidService.new(lead, campaign)
bid_request = bid_service.solicit_bids!
puts "\nCreated bid request #{bid_request.id} with expiration at #{bid_request.expires_at}"