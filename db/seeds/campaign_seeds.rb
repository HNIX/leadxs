# Campaign Seeds
account = Account.first
ActsAsTenant.with_tenant(account) do
  account.verticals.each do |vertical|
    # Create a ping-post campaign
    unless Campaign.exists?(name: "#{vertical.name} Ping-Post Campaign", account_id: account.id)
      campaign = Campaign.create!(
        name: "#{vertical.name} Ping-Post Campaign",
        vertical: vertical,
        status: "active",
        campaign_type: "ping_post",
        description: "This campaign handles ping-post leads for #{vertical.name}",
        distribution_method: "highest_bid",
        distribution_schedule_enabled: true,
        distribution_schedule_days: ["monday", "tuesday", "wednesday", "thursday", "friday"],
        distribution_schedule_start_time: "08:00",
        distribution_schedule_end_time: "17:00",
        account_id: account.id
      )
      puts "Created ping-post campaign for #{vertical.name}"
    end
    
    # Create a direct campaign
    unless Campaign.exists?(name: "#{vertical.name} Direct Campaign", account_id: account.id)
      campaign = Campaign.create!(
        name: "#{vertical.name} Direct Campaign",
        vertical: vertical,
        status: "draft",
        campaign_type: "direct",
        description: "This campaign handles direct leads for #{vertical.name}",
        distribution_method: "round_robin",
        distribution_schedule_enabled: false,
        account_id: account.id
      )
      puts "Created direct campaign for #{vertical.name}"
    end
  end
end