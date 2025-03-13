# Disable the filter that's causing issues
filter = DistributionFilter.find(2)

# Option 1: Update to not apply to all distributions
filter.update(apply_to_all: false)
puts "Filter updated to not apply to all distributions"

# Option 2: Remove all distributions from the filter
filter.distributions.clear
puts "Removed all distributions from the filter."

# Option 3: Change the filter status to inactive
filter.update(status: 'inactive')
puts "Filter set to inactive"

# Now let's try creating a bid request again
campaign = Campaign.first
lead = Lead.last

# Create a new bid request manually with our updated filter
bid_service = BidService.new(lead, campaign)
bid_request = bid_service.solicit_bids!

puts "Created bid request #{bid_request.id} with expiration at #{bid_request.expires_at}"
puts "Bid request has #{campaign.eligible_distributions_for_bidding(lead.field_values_hash).count} eligible distributions."