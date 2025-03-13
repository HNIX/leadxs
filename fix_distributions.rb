# Fix distributions to have bidding enabled
campaign = Campaign.first

# Get all active distributions
distributions = campaign.distributions.active
puts "Found #{distributions.count} active distributions"

# Check if any have bidding_enabled?
puts "Checking which distributions have bidding enabled:"
distributions.each do |dist|
  puts "Distribution #{dist.id}: #{dist.name}"
  puts "  Active: #{dist.active?}"
  puts "  Base bid amount: #{dist.base_bid_amount.inspect}"
  puts "  Bidding enabled?: #{dist.bidding_enabled?}"
  
  reason = if !dist.active?
             "not active"
           elsif !dist.base_bid_amount.present?
             "base_bid_amount not set"
           elsif dist.base_bid_amount <= 0
             "base_bid_amount not > 0"
           else
             "unknown reason"
           end
  
  puts "  Reason: #{reason}"
  
  # Fix the distribution by setting a base bid amount
  if !dist.bidding_enabled?
    dist.update(base_bid_amount: 10.0)
    puts "  FIXED: Updated base_bid_amount to 10.0"
    puts "  New bidding_enabled?: #{dist.bidding_enabled?}"
  end
  
  puts ""
end

# Now check if distributions are eligible
lead = Lead.last
lead_data = lead.field_values_hash
eligible = campaign.eligible_distributions_for_bidding(lead_data)
puts "After fixing distributions:"
puts "Eligible distributions: #{eligible.count}"
puts "Eligible IDs: #{eligible.map(&:id).join(', ')}"

# Create a test bid request
bid_service = BidService.new(lead, campaign)
bid_request = bid_service.solicit_bids!
puts "\nCreated bid request #{bid_request.id} with expiration at #{bid_request.expires_at}"