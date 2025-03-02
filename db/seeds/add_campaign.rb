account = Account.first
vertical = account.verticals.first
ActsAsTenant.with_tenant(account) do
  # Skip the automatic creation of campaign fields for now
  Campaign.skip_callback(:create, :after, :create_campaign_fields_from_vertical)
  
  campaign = Campaign.create!(
    name: "Test Campaign", 
    vertical: vertical, 
    status: "active", 
    campaign_type: "ping_post", 
    description: "Test", 
    distribution_method: "highest_bid", 
    distribution_schedule_enabled: false, 
    account_id: account.id
  )
  
  # Re-enable the callback for future campaigns
  Campaign.set_callback(:create, :after, :create_campaign_fields_from_vertical)
  
  puts "Created campaign: #{campaign.name} with ID: #{campaign.id}"
end