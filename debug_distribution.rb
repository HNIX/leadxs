# This script diagnoses distribution eligibility issues

# Get a test campaign and lead
campaign = Campaign.first
lead = Lead.last
lead_data = lead.field_values_hash

puts "== Debugging Distribution Eligibility =="
puts "Campaign: #{campaign.id} (#{campaign.name})"
puts "Lead: #{lead.id}" 
puts "Distribution method: #{campaign.distribution_method}"
puts ""

puts "== Campaign Distribution Config =="
puts "Uses bidding: #{campaign.use_bidding_system?}"
puts "Bid timeout: #{campaign.bid_timeout_seconds} seconds"
puts "Distribution method: #{campaign.distribution_method}" 
puts ""

puts "== Active Distributions =="
active_distributions = campaign.distributions.active
puts "Total active: #{active_distributions.count}"

active_distributions.each do |dist|
  puts "- Distribution #{dist.id}: #{dist.name}"
  puts "  Active: #{dist.active?}"
  puts "  Base bid amount: #{dist.base_bid_amount || 'nil'}"
  puts "  Bidding enabled: #{dist.bidding_enabled?}"
  puts "  Endpoint: #{dist.bid_endpoint_url || dist.endpoint_url}"
  
  # Check if any filters apply to this distribution
  filters = DistributionFilter.where(campaign: campaign, status: 'active')
  applicable_filters = filters.select { |filter| filter.applies_to?(dist) }
  
  if applicable_filters.any?
    puts "  Filters: #{applicable_filters.count} applicable"
    
    # Check if all filters pass
    passing_filters = []
    failing_filters = []
    
    applicable_filters.each do |filter|
      if filter.passes?(lead_data)
        passing_filters << filter.id
      else
        failing_filters << filter.id
      end
    end
    
    puts "  - Passing filters: #{passing_filters.join(', ')}"
    puts "  - Failing filters: #{failing_filters.join(', ')}"
    
    if failing_filters.any?
      puts "  ❌ Distribution excluded due to failing filters"
    else
      puts "  ✅ Distribution passes all filters"
    end
  else
    puts "  ✅ No filters apply to this distribution"
  end
  
  if !dist.bidding_enabled?
    puts "  ❌ Distribution excluded because bidding is not enabled"
  end
  
  puts ""
end

puts "== Eligible Distributions =="
eligible = campaign.eligible_distributions_for_bidding(lead_data)
puts "Total eligible: #{eligible.count}"
puts "Eligible IDs: #{eligible.map(&:id).join(', ')}"