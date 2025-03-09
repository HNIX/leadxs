namespace :bidding do
  desc "Setup bidding system with test data"
  task setup: :environment do
    if Rails.env.production?
      puts "This task should not be run in production environment!"
      exit
    end
    
    puts "Setting up bidding system with test data..."
    
    require_relative "../../../db/seeds/bidding/setup_bidding_system"
    Seeds::Bidding::SetupBiddingSystem.setup
    
    puts "Bidding system setup complete!"
  end
  
  desc "Generate bid analytics for the past month"
  task analytics: :environment do
    puts "Generating bid analytics for test data..."
    
    # Find the first admin account
    admin_user = User.joins(:account_users).where(account_users: { roles: { admin: true } }).first
    
    unless admin_user
      puts "No admin user found. Please run bidding:setup first."
      exit
    end
    
    # Get the admin's primary account
    account = admin_user.accounts.first
    
    unless account
      puts "No account found for admin. Please run bidding:setup first."
      exit
    end
    
    # Generate analytics for different time periods
    puts "Generating daily snapshots..."
    30.downto(1) do |days_ago|
      date = Date.current - days_ago.days
      GenerateBidAnalyticsJob.new.perform({
        period_type: :daily,
        for_date: date,
        account_id: account.id,
        all_campaigns: true,
        all_distributions: true
      })
      
      print "." # Progress indicator
    end
    
    puts "\nGenerating weekly snapshots..."
    4.downto(1) do |weeks_ago|
      date = Date.current - (weeks_ago * 7).days
      GenerateBidAnalyticsJob.new.perform({
        period_type: :weekly,
        for_date: date,
        account_id: account.id,
        all_campaigns: true,
        all_distributions: true
      })
      
      print "."
    end
    
    puts "\nGenerating monthly snapshots..."
    3.downto(1) do |months_ago|
      date = Date.current - months_ago.months
      GenerateBidAnalyticsJob.new.perform({
        period_type: :monthly,
        for_date: date,
        account_id: account.id,
        all_campaigns: true,
        all_distributions: true
      })
      
      print "."
    end
    
    puts "\nBid analytics generation complete!"
  end
  
  desc "Clean up all bidding system test data (warning: deletes data!)"
  task clean: :environment do
    if Rails.env.production?
      puts "This task should not be run in production environment!"
      exit
    end
    
    puts "Cleaning up bidding system test data..."
    
    # Find the first admin account
    admin_user = User.joins(:account_users).where(account_users: { roles: { admin: true } }).first
    
    unless admin_user
      puts "No admin user found. Nothing to clean up."
      exit
    end
    
    # Get the admin's primary account
    account = admin_user.accounts.first
    
    unless account
      puts "No account found for admin. Nothing to clean up."
      exit
    end
    
    # Use ActsAsTenant to ensure we only delete the test account's data
    ActsAsTenant.with_tenant(account) do
      # Delete analytics first (since they depend on bids and distributions)
      BidAnalyticSnapshot.delete_all
      puts "Deleted bid analytics"
      
      # Delete bids and bid requests
      Bid.delete_all
      puts "Deleted bids"
      
      # Update leads to remove bid request associations if the column exists
      if Lead.column_names.include?("bid_request_id")
        Lead.where.not(bid_request_id: nil).update_all(bid_request_id: nil)
        puts "Removed bid request associations from leads"
      end
      
      BidRequest.delete_all
      puts "Deleted bid requests"
      
      # Delete distributions and campaign distributions
      MappedField.delete_all
      puts "Deleted mapped fields"
      
      CampaignDistribution.delete_all
      puts "Deleted campaign distributions"
      
      # Delete headers that belong to distributions
      Header.delete_all
      puts "Deleted headers"
      
      Distribution.delete_all
      puts "Deleted distributions"
    end
    
    puts "Bidding system cleanup complete!"
  end
  
  desc "Reset bidding system (clean and setup)"
  task reset: :environment do
    if Rails.env.production?
      puts "This task should not be run in production environment!"
      exit
    end
    
    Rake::Task["bidding:clean"].invoke
    Rake::Task["bidding:setup"].invoke
  end
end