# Get a campaign with distributions
campaign = Campaign.first

# Update the timeout to be longer (2 minutes)
campaign.update(bid_timeout_seconds: 120)
puts "Campaign updated with 120 second timeout"

# Create a test lead
lead = Lead.last
puts "Using lead #{lead.id}"

# Create a new bid request manually with our new timeout
bid_service = BidService.new(lead, campaign)
bid_request = bid_service.solicit_bids!
puts "Created bid request #{bid_request.id} with expiration at #{bid_request.expires_at}"