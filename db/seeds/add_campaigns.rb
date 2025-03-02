account = Account.first
vertical = account.verticals.first
ActsAsTenant.with_tenant(account) do
  # Skip the automatic creation of campaign fields for now
  Campaign.skip_callback(:create, :after, :create_campaign_fields_from_vertical)
  
  # Create a direct campaign
  campaign = Campaign.create!(
    name: "Direct Campaign", 
    vertical: vertical, 
    status: "draft", 
    campaign_type: "direct", 
    description: "A direct campaign for testing", 
    distribution_method: "round_robin", 
    distribution_schedule_enabled: false, 
    account_id: account.id
  )
  puts "Created campaign: #{campaign.name} with ID: #{campaign.id}"
  
  # Create a calls campaign with schedule
  campaign = Campaign.create!(
    name: "Calls Campaign", 
    vertical: vertical, 
    status: "paused", 
    campaign_type: "calls", 
    description: "A call campaign with schedule", 
    distribution_method: "waterfall", 
    distribution_schedule_enabled: true, 
    distribution_schedule_days: ["monday", "tuesday", "wednesday", "thursday", "friday"], 
    distribution_schedule_start_time: "09:00", 
    distribution_schedule_end_time: "17:00", 
    account_id: account.id
  )
  puts "Created campaign: #{campaign.name} with ID: #{campaign.id}"
  
  # Re-enable the callback for future campaigns
  Campaign.set_callback(:create, :after, :create_campaign_fields_from_vertical)
end