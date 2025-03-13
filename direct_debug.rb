# This script directly debugs distribution bidding eligibility
# Let's try to find out exactly what's going wrong

# Set up a test lead and campaign
campaign = Campaign.first
lead = Lead.last

# First, check the distribution method
puts "Campaign #{campaign.id} distribution_method: #{campaign.distribution_method}"
puts "Uses bidding system? #{campaign.use_bidding_system?}"

# Let's check the exact logic that determines if a distribution is eligible for bidding
puts "\nChecking eligible_distributions_for_bidding logic:"
all_distributions = campaign.distributions.active
puts "Total active distributions: #{all_distributions.count}"

result = campaign.eligible_distributions_for_bidding(lead.field_values_hash)
puts "Result of eligible_distributions_for_bidding: #{result.count} distributions"

# Let's implement our own version to debug
puts "\nDEBUG: Step by step eligibility check:"
# First check: does this campaign use a bidding system?
unless campaign.distribution_method.in?(['highest_bid', 'weighted_random', 'waterfall'])
  puts "❌ Campaign distribution method not compatible with bidding"
  exit
end

puts "✅ Campaign distribution method (#{campaign.distribution_method}) is compatible with bidding"

# Second step: get distributions that pass all filters
puts "\nGetting filtered distributions:"
filtered_distributions = DistributionFilter.filter_distributions(all_distributions, lead.field_values_hash, campaign)
puts "After filtering: #{filtered_distributions.count} distributions"

# Third step: check which distributions have bidding enabled
bidding_enabled_distributions = filtered_distributions.select { |dist| dist.respond_to?(:bidding_enabled?) && dist.bidding_enabled? }
puts "After checking bidding_enabled?: #{bidding_enabled_distributions.count} distributions"

puts "\nDetailed bidding enabled check:"
filtered_distributions.each do |dist|
  puts "Distribution #{dist.id}: #{dist.name}"
  
  if !dist.respond_to?(:bidding_enabled?)
    puts "  ❌ Doesn't respond to bidding_enabled?"
  elsif !dist.bidding_enabled?
    reason = if !dist.active?
               "not active"
             elsif !dist.base_bid_amount.present?
               "no base_bid_amount"
             elsif dist.base_bid_amount <= 0
               "base_bid_amount not > 0"
             else
               "unknown reason"
             end
    puts "  ❌ bidding_enabled? returns false (#{reason})"
  else
    puts "  ✅ bidding_enabled? returns true"
  end
end

# Now let's modify a distribution to make it eligible
dist = all_distributions.first
if dist && !dist.bidding_enabled?
  puts "\nFixing distribution #{dist.id}:"
  puts "  Before: base_bid_amount = #{dist.base_bid_amount || 'nil'}"
  dist.update(base_bid_amount: 10.0)
  puts "  After: base_bid_amount = #{dist.base_bid_amount}"
  puts "  bidding_enabled? now returns: #{dist.bidding_enabled?}"
  
  result = campaign.eligible_distributions_for_bidding(lead.field_values_hash)
  puts "  Result of eligible_distributions_for_bidding: #{result.count} distributions"
  
  # Create a bid request with our updated distribution
  bid_service = BidService.new(lead, campaign)
  bid_request = bid_service.solicit_bids!
  puts "\nCreated bid request #{bid_request.id} with expiration at #{bid_request.expires_at}"
end