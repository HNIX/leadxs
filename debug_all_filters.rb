# Debug all filters for a campaign
campaign = Campaign.first
lead = Lead.last
lead_data = lead.field_values_hash

puts "Debugging filters for campaign: #{campaign.id} (#{campaign.name})"
puts "Lead: #{lead.id}"

# Get all distribution filters for the campaign
filters = DistributionFilter.where(campaign: campaign)
puts "\nFound #{filters.count} filters:"

filters.each do |filter|
  campaign_field = filter.campaign_field
  field_value = lead.field_value(campaign_field.id)
  
  puts "\nFilter ##{filter.id}:"
  puts "Status: #{filter.status}"
  puts "Field: #{campaign_field.name} (#{campaign_field.field_type})"
  puts "Operator: #{filter.operator}"
  puts "Value: #{filter.value.inspect}"
  puts "Min Value: #{filter.min_value.inspect}"
  puts "Max Value: #{filter.max_value.inspect}"
  puts "Apply to all: #{filter.apply_to_all}"
  puts "Lead value: #{field_value.inspect}"
  
  # Check if filter passes for this lead data
  passes = filter.passes?(lead_data)
  puts "Filter passes? #{passes}"
  
  if !passes
    # Show the filter condition
    condition = case filter.operator
                when 'equals'
                  "#{field_value.inspect} == #{filter.value.inspect}"
                when 'not_equals'
                  "#{field_value.inspect} != #{filter.value.inspect}"
                when 'contains'
                  "#{field_value.inspect}.to_s.include?(#{filter.value.inspect})"
                when 'does_not_contain'
                  "!#{field_value.inspect}.to_s.include?(#{filter.value.inspect})"
                when 'greater_than'
                  "#{field_value.inspect}.to_f > #{filter.value.inspect}.to_f"
                when 'less_than'
                  "#{field_value.inspect}.to_f < #{filter.value.inspect}.to_f"
                when 'between'
                  "#{field_value.inspect}.to_f >= #{filter.min_value.inspect}.to_f && #{field_value.inspect}.to_f <= #{filter.max_value.inspect}.to_f"
                else
                  "Unknown operator: #{filter.operator}"
                end
    puts "Condition failed: #{condition}"
  end
end

# Let's get all active distributions
distributions = campaign.distributions.active
puts "\nFound #{distributions.count} active distributions"

# Now let's check each distribution with each filter
puts "\nChecking filters against each distribution:"
distributions.each do |dist|
  puts "Distribution #{dist.id}: #{dist.name}"
  
  # Get applicable filters for this distribution
  applicable_filters = filters.select { |filter| filter.applies_to?(dist) }
  puts "  #{applicable_filters.count} applicable filters"
  
  if applicable_filters.any?
    applicable_filters.each do |filter|
      passes = filter.passes?(lead_data)
      puts "  - Filter #{filter.id} (#{filter.campaign_field.name}): #{passes ? '✅ passes' : '❌ fails'}"
    end
  else
    puts "  No filters apply to this distribution"
  end
end

# Let's fix the filtering issue by disabling all filters for testing
puts "\nDisabling all filters for testing:"
filters.each do |filter|
  filter.update(status: 'inactive')
  puts "Filter #{filter.id} set to inactive"
end

# Now check if distributions are eligible
eligible = campaign.eligible_distributions_for_bidding(lead_data)
puts "\nAfter disabling filters:"
puts "Eligible distributions: #{eligible.count}"
puts "Eligible IDs: #{eligible.map(&:id).join(', ')}"

# Create a test bid request
bid_service = BidService.new(lead, campaign)
bid_request = bid_service.solicit_bids!
puts "\nCreated bid request #{bid_request.id} with expiration at #{bid_request.expires_at}"