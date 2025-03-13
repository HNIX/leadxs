namespace :bidding do
  desc "Debug bid requests that failed to complete"
  task debug: :environment do
    # Find bid requests that might be stuck
    active_expired = BidRequest.where(status: 'active')
                               .where('expires_at < ?', 5.minutes.ago)
                               .order(created_at: :desc)
                               .limit(10)
    
    puts "Found #{active_expired.count} active bid requests that have expired"
    
    active_expired.each do |br|
      puts "BidRequest ##{br.id} (Campaign ##{br.campaign_id})"
      puts "  Created: #{br.created_at}, Expires: #{br.expires_at}"
      puts "  Bids: #{br.bids.count}"
      
      br.bids.each do |bid|
        puts "    Bid ##{bid.id}: #{bid.amount} (#{bid.status}) from #{bid.distribution.name}"
      end
      
      if br.lead.present?
        puts "  Has lead: Yes (#{br.lead.id})"
      else
        puts "  Has lead: No"
      end
    end
    
    # Look for distributions that have no bids
    no_bid_distributions = Distribution.joins('LEFT JOIN bids ON bids.distribution_id = distributions.id')
                                      .where('bids.id IS NULL')
                                      .distinct
    
    puts "\nDistributions with no bids: #{no_bid_distributions.count}"
    no_bid_distributions.each do |dist|
      puts "  #{dist.id}: #{dist.name} (bidding_enabled: #{dist.bidding_enabled?})"
      puts "    base_bid_amount: #{dist.base_bid_amount}, status: #{dist.status}"
    end
  end
  
  desc "Fix stuck bid requests by forcing expiration and processing"
  task fix_stuck: :environment do
    # Find bid requests that might be stuck
    stuck_requests = BidRequest.where(status: ['active', 'pending'])
                               .where('expires_at < ?', 10.minutes.ago)
                               
    count = stuck_requests.count
    puts "Found #{count} stuck bid requests to fix"
    
    processed = 0
    stuck_requests.find_each do |br|
      # Process within tenant context
      ActsAsTenant.with_tenant(br.account) do
        begin
          puts "Processing BidRequest ##{br.id} (Campaign ##{br.campaign_id})"
          
          # Mark as expired
          br.update(status: :expired)
          
          # Get winning bid if any
          winning_bid = br.winning_bid
          
          if winning_bid.present?
            puts "  Found winning bid ##{winning_bid.id} (#{winning_bid.amount})"
            
            # Process the bid
            if br.lead.present?
              result = br.complete_bidding_and_distribute!
              puts "  Lead distribution result: #{result}"
            else
              result = winning_bid.accept!
              puts "  Bid acceptance result: #{result}"
            end
          else
            puts "  No winning bid found"
          end
          
          processed += 1
        rescue => e
          puts "  ERROR: #{e.message}"
        end
      end
    end
    
    puts "Successfully processed #{processed}/#{count} stuck bid requests"
  end
  
  desc "Show bid request statistics"
  task stats: :environment do
    total = BidRequest.count
    completed = BidRequest.where(status: 'completed').count
    expired = BidRequest.where(status: 'expired').count
    pending = BidRequest.where(status: ['active', 'pending']).count
    
    puts "Bid request statistics:"
    puts "  Total: #{total}"
    puts "  Completed: #{completed} (#{(completed.to_f / total * 100).round(1)}%)" if total > 0
    puts "  Expired: #{expired} (#{(expired.to_f / total * 100).round(1)}%)" if total > 0
    puts "  Pending: #{pending} (#{(pending.to_f / total * 100).round(1)}%)" if total > 0
    
    # Bids statistics
    total_bids = Bid.count
    accepted_bids = Bid.where(status: 'accepted').count
    rejected_bids = Bid.where(status: 'rejected').count
    
    puts "\nBid statistics:"
    puts "  Total: #{total_bids}"
    puts "  Accepted: #{accepted_bids} (#{(accepted_bids.to_f / total_bids * 100).round(1)}%)" if total_bids > 0
    puts "  Rejected: #{rejected_bids} (#{(rejected_bids.to_f / total_bids * 100).round(1)}%)" if total_bids > 0
    
    # Average bids per request
    avg_bids = total > 0 ? (total_bids.to_f / total).round(2) : 0
    puts "\nAverage bids per request: #{avg_bids}"
    
    # Completion time statistics
    requests_with_completion = BidRequest.where.not(completed_at: nil)
    if requests_with_completion.exists?
      completion_durations = requests_with_completion.map do |br| 
        (br.completed_at - br.created_at).to_i if br.completed_at.present?
      end.compact
      
      if completion_durations.any?
        avg_duration = (completion_durations.sum.to_f / completion_durations.size).round(2)
        max_duration = completion_durations.max
        min_duration = completion_durations.min
        
        puts "\nCompletion time statistics (seconds):"
        puts "  Average: #{avg_duration}"
        puts "  Maximum: #{max_duration}"
        puts "  Minimum: #{min_duration}"
      end
    end
  end
  
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