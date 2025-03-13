# Seeds for generating diverse source performance data
# This generates multiple sources with different performance characteristics
# and creates associated leads, bids, and compliance records

# Constants for data generation
CAMPAIGN_COUNT = 2
SOURCES_PER_CAMPAIGN = 5
LEADS_PER_SOURCE_MIN = 20
LEADS_PER_SOURCE_MAX = 100
DAYS_OF_DATA = 30

puts "Creating source performance seed data..."

# Skip if we're not in development environment
unless Rails.env.development?
  puts "Skipping source performance data for non-development environment."
  return
end

# Make sure we have the required accounts and campaigns
account = Account.first || Account.create!(name: "Demo Account", domain: "example.com", subdomain: "demo")
Current.account = account

# Make sure we have some companies for sources and distributions
source_companies = []
3.times do |i|
  source_companies << Company.find_or_create_by!(name: "Source Company #{i+1}", account: account)
end

buyer_companies = []
3.times do |i|
  buyer_companies << Company.find_or_create_by!(name: "Buyer Company #{i+1}", account: account)
end

# Create or use existing vertical and campaign
vertical = Vertical.find_or_create_by!(name: "Lead Generation", account: account) do |v|
  v.description = "Vertical for lead generation"
  v.primary_category = "Lead Generation"
  v.archived = false
end

CAMPAIGN_COUNT.times do |c|
  campaign = Campaign.find_or_create_by!(name: "Performance Test Campaign #{c+1}", account: account) do |campaign|
    campaign.vertical = vertical
    campaign.status = "active"
    campaign.campaign_type = "ping_post"
    campaign.description = "Campaign for testing source performance"
    
    # Bidding settings
    campaign.bid_timeout_seconds = 5
    campaign.minimum_bid_amount = 5.0
    campaign.distribution_method = "highest_bid"
    campaign.multi_distribution_strategy = "single"
  end

  # Create Fields for the campaign if they don't exist
  unless CampaignField.where(campaign: campaign).exists?
    # Create basic lead fields
    CampaignField.create!(
      campaign: campaign,
      name: "first_name",
      label: "First Name",
      field_type: "text",
      required: true,
      position: 1
    )
    
    CampaignField.create!(
      campaign: campaign,
      name: "last_name",
      label: "Last Name", 
      field_type: "text",
      required: true,
      position: 2
    )
    
    CampaignField.create!(
      campaign: campaign,
      name: "email",
      label: "Email Address",
      field_type: "email",
      required: true,
      position: 3,
      share_during_bidding: true
    )
    
    CampaignField.create!(
      campaign: campaign,
      name: "phone",
      label: "Phone Number",
      field_type: "phone",
      required: true,
      position: 4
    )
    
    CampaignField.create!(
      campaign: campaign,
      name: "address",
      label: "Address",
      field_type: "text",
      required: false,
      position: 5
    )
    
    CampaignField.create!(
      campaign: campaign,
      name: "city",
      label: "City",
      field_type: "text",
      required: false,
      position: 6,
      share_during_bidding: true
    )
    
    CampaignField.create!(
      campaign: campaign,
      name: "state",
      label: "State",
      field_type: "text",
      required: false,
      position: 7,
      share_during_bidding: true
    )
    
    CampaignField.create!(
      campaign: campaign,
      name: "zip",
      label: "Zip Code",
      field_type: "text",
      required: false,
      position: 8,
      share_during_bidding: true
    )
  end

  # Create a validation rule if none exist
  unless ValidationRule.where(validatable_type: 'Campaign', validatable_id: campaign.id).exists?
    ValidationRule.create!(
      validatable: campaign,
      account: account,
      name: "Email Validation",
      rule_type: "pattern",
      condition: "field('email').match(/^[\\w+\\-.]+@[a-z\\d\\-]+(\\.[a-z\\d\\-]+)*\\.[a-z]+$/i)",
      error_message: "Please enter a valid email address",
      active: true,
      position: 1
    )
  end

  # Make sure we have at least 3 distributions to work with
  buyer_names = ["Performance Test Buyer 1", "Performance Test Buyer 2", "Performance Test Buyer 3"]
  
  buyer_names.each_with_index do |name, i|
    # Check if distribution already exists
    distribution = Distribution.find_by(name: name, account: account)
    
    # Create if it doesn't exist
    if distribution.nil?
      distribution = Distribution.create!(
        name: name,
        company: buyer_companies.sample,
        account: account,
        endpoint_url: "https://example.com/leads",
        request_method: "post",
        request_format: "json", 
        status: "active",
        bidding_strategy: "manual",
        base_bid_amount: rand(10.0..25.0).round(2),
        min_bid_amount: 5.0,
        max_bid_amount: 40.0
      )
    end
    
    # Make sure the distribution is linked to this campaign
    unless CampaignDistribution.exists?(campaign: campaign, distribution: distribution)
      CampaignDistribution.create!(
        campaign: campaign,
        distribution: distribution,
        priority: i + 1,
        active: true
      )
    end
  end
  
  # Create sources with different performance characteristics
  SOURCES_PER_CAMPAIGN.times do |i|
    # Create sources with different characteristics
    source_name = "Test Source #{i+1} for Campaign #{campaign.id}"
    
    # Check if source already exists
    source = Source.find_by(name: source_name, campaign: campaign, account: account)
    
    # If it doesn't exist, create it
    if source.nil?
      payout_method = i.even? ? 'fixed' : 'percentage'
      payout = i.even? ? rand(3.0..8.0).round(2) : nil
      margin = i.even? ? nil : rand(0.3..0.7).round(2)
      
      source = Source.create!(
        name: source_name,
        campaign: campaign,
        account: account,
        company: source_companies.sample,
        token: SecureRandom.hex(10),
        status: "active",
        integration_type: "affiliate",
        payout_method: payout_method,
        payout: payout,
        margin: margin,
        minimum_acceptable_bid: rand(4.0..7.0).round(2),
        daily_budget: rand(500..1000),
        monthly_budget: rand(5000..10000),
        notes: "Auto-generated test source #{i+1}"
      )
    end
    
    # Generate a varying number of leads for each source with different performance metrics
    lead_count = rand(LEADS_PER_SOURCE_MIN..LEADS_PER_SOURCE_MAX)
    acceptance_rate = case i % 5
    when 0 then rand(0.85..0.95) # Excellent source
    when 1 then rand(0.70..0.85) # Good source
    when 2 then rand(0.50..0.70) # Average source
    when 3 then rand(0.30..0.50) # Below average source
    when 4 then rand(0.10..0.30) # Poor source
    end
    
    puts "Generating #{lead_count} leads for #{source.name} with #{(acceptance_rate * 100).round}% acceptance rate"
    
    # Generate leads over the last DAYS_OF_DATA days
    lead_count.times do |j|
      # Create a lead with random data and timestamp
      created_at = rand(DAYS_OF_DATA).days.ago + rand(24).hours
      
      # Generate lead data
      lead_data = {
        "first_name" => ["John", "Jane", "Mike", "Sarah", "David", "Lisa"].sample,
        "last_name" => ["Smith", "Johnson", "Williams", "Brown", "Jones", "Miller"].sample,
        "email" => "test#{rand(1000)}@example.com",
        "phone" => "555-#{rand(100..999)}-#{rand(1000..9999)}",
        "address" => "#{rand(100..9999)} Main St",
        "city" => ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia"].sample,
        "state" => ["NY", "CA", "IL", "TX", "AZ", "PA"].sample,
        "zip" => "#{rand(10000..99999)}"
      }
      
      # Create the lead
      lead = Lead.create!(
        campaign: campaign,
        source: source,
        account: account,
        status: :new_lead,
        created_at: created_at,
        updated_at: created_at
      )
      
      # Create LeadData records for each field
      lead_data.each do |field_name, value|
        campaign_field = campaign.campaign_fields.find_by(name: field_name)
        if campaign_field
          LeadData.create!(
            lead: lead,
            campaign_field: campaign_field,
            value: value
          )
        end
      end
      
      # Create a bid request with randomized timing
      shared_data = lead_data.select { |k, v| campaign.campaign_fields.find_by(name: k)&.share_during_bidding }
      bid_request = BidRequest.create!(
        campaign: campaign,
        lead: lead,
        account: account,
        status: :pending,
        unique_id: SecureRandom.uuid,
        anonymized_data: shared_data,
        expires_at: created_at + campaign.bid_timeout_seconds.seconds,
        created_at: created_at,
        updated_at: created_at
      )
      
      # Generate bids from distributions (buyers)
      campaign.distributions.order("RANDOM()").limit(rand(1..campaign.distributions.count)).each_with_index do |distribution, bid_index|
        # Decide if this bid will be successful based on the source's acceptance rate
        is_accepted = rand < acceptance_rate
        
        # Calculate bid amount with some variance
        variance = rand(-0.2..0.2)
        bid_amount = distribution.base_bid_amount * (1 + variance)
        
        # Ensure bid amount is within distribution's limits
        bid_amount = [bid_amount, distribution.min_bid_amount || 0].max
        bid_amount = [bid_amount, distribution.max_bid_amount || 100].min
        
        # Create the bid with a slight delay after bid request
        bid_created_at = created_at + rand(1..10).seconds
        bid = Bid.create!(
          bid_request: bid_request,
          distribution: distribution,
          account: account,
          amount: bid_amount.round(2),
          status: :pending,
          created_at: bid_created_at,
          updated_at: bid_created_at
        )
        
        # Add bid to the analytics data
        if is_accepted && bid_index == 0  # Only accept the first bid if this lead should be accepted
          bid.update!(
            status: :accepted,
            updated_at: bid_created_at + rand(1..5).seconds
          )
          
          bid_request.update!(
            status: :completed,
            updated_at: bid_created_at + rand(1..5).seconds
          )
          
          lead.update!(
            status: :distributed,
            updated_at: bid_created_at + rand(1..5).seconds
          )
          
          # Create compliance records
          ComplianceRecord.create!(
            record: lead,
            account: account,
            event_type: ComplianceRecord::LEAD_PROCESSING,
            action: ComplianceRecord::CREATED,
            occurred_at: created_at,
            ip_address: "127.0.0.1",
            user_agent: "Seed Data Generator"
          )
          
          # Skip consent records for this seed file
          # ConsentRecord creation tries to access Current.request which isn't available in seeds
          
          # Skip DataAccessRecord for this seed file to avoid potential Current.request issues
        else
          # Generate a mix of rejected/expired/error bids for non-accepted leads
          status_options = [:rejected, :expired, :error]
          weights = [0.7, 0.2, 0.1]  # 70% rejected, 20% expired, 10% error
          cumulative_weights = weights.each_with_index.map { |w, i| weights[0..i].sum }
          rand_val = rand
          status_index = cumulative_weights.index { |w| rand_val <= w }
          
          bid.update!(
            status: status_options[status_index],
            updated_at: bid_created_at + rand(2..15).seconds
          )
          
          # Update bid request status based on all bids
          if bid_index == campaign.distributions.count - 1  # If this is the last bid
            # If all bids failed, mark the bid request as canceled 
            bid_request.update!(
              status: :canceled,
              updated_at: bid_created_at + rand(2..15).seconds
            )
            
            lead.update!(
              status: :rejected,
              updated_at: bid_created_at + rand(2..15).seconds
            )
          end
        end
      end
      
      # Generate bid analytic snapshots for different time periods
      %w[hourly daily weekly monthly].each do |period_type|
        if j % 10 == 0  # Only create snapshots for a subset of leads to avoid too much data
          snapshot_time = case period_type
          when 'hourly' then created_at.beginning_of_hour
          when 'daily' then created_at.beginning_of_day
          when 'weekly' then created_at.beginning_of_week
          when 'monthly' then created_at.beginning_of_month
          end
          
          period_end = case period_type
          when 'hourly' then snapshot_time + 1.hour
          when 'daily' then snapshot_time + 1.day
          when 'weekly' then snapshot_time + 1.week
          when 'monthly' then snapshot_time + 1.month
          end
          
          # Find or create a snapshot for this period
          snapshot = BidAnalyticSnapshot.find_or_create_by(
            campaign: campaign,
            period_type: period_type,
            period_start: snapshot_time,
            period_end: period_end,
            account: account
          ) do |s|
            s.total_bids = 0
            s.accepted_bids = 0
            s.rejected_bids = 0
            s.expired_bids = 0
            s.avg_bid_amount = 0
            s.max_bid_amount = 0
            s.min_bid_amount = 0
            s.conversion_count = 0
            s.total_revenue = 0
            s.metrics = {
              'bid_requests_sent' => 0,
              'avg_response_time' => 0,
              'campaign_stats' => {},
              'distribution_stats' => {}
            }
          end
          
          # Update the snapshot with this lead's data
          snapshot.total_bids += bid_request.bids.count
          snapshot.accepted_bids += bid_request.bids.where(status: 'accepted').count
          snapshot.rejected_bids += bid_request.bids.where(status: 'rejected').count
          snapshot.expired_bids += bid_request.bids.where(status: 'expired').count
          
          accepted_bid = bid_request.bids.find_by(status: 'accepted')
          if accepted_bid
            new_total = snapshot.avg_bid_amount * (snapshot.accepted_bids - 1) + accepted_bid.amount
            snapshot.avg_bid_amount = snapshot.accepted_bids > 0 ? (new_total / snapshot.accepted_bids) : 0
            snapshot.max_bid_amount = [snapshot.max_bid_amount, accepted_bid.amount].max
            snapshot.min_bid_amount = snapshot.min_bid_amount > 0 ? [snapshot.min_bid_amount, accepted_bid.amount].min : accepted_bid.amount
            snapshot.total_revenue += accepted_bid.amount
          end
          
          # Update metrics hash
          metrics = snapshot.metrics
          metrics['bid_requests_sent'] += 1
          
          # Update campaign stats
          campaign_id = campaign.id.to_s
          metrics['campaign_stats'][campaign_id] ||= {
            'total_bids' => 0,
            'accepted_bids' => 0,
            'acceptance_rate' => 0,
            'avg_amount' => 0
          }
          
          metrics['campaign_stats'][campaign_id]['total_bids'] += bid_request.bids.count
          accepted_count = bid_request.bids.where(status: 'accepted').count
          metrics['campaign_stats'][campaign_id]['accepted_bids'] += accepted_count
          total_accepted = metrics['campaign_stats'][campaign_id]['accepted_bids']
          total_bids = metrics['campaign_stats'][campaign_id]['total_bids']
          metrics['campaign_stats'][campaign_id]['acceptance_rate'] = total_bids > 0 ? (total_accepted.to_f / total_bids * 100).round(2) : 0
          
          if accepted_bid
            current_avg = metrics['campaign_stats'][campaign_id]['avg_amount'].to_f
            new_total = current_avg * (total_accepted - 1) + accepted_bid.amount.to_f
            metrics['campaign_stats'][campaign_id]['avg_amount'] = total_accepted > 0 ? (new_total / total_accepted).round(2) : 0
          end
          
          # Update distribution stats
          bid_request.bids.each do |bid|
            dist_id = bid.distribution_id.to_s
            metrics['distribution_stats'][dist_id] ||= {
              'total_bids' => 0,
              'accepted_bids' => 0,
              'acceptance_rate' => 0,
              'avg_amount' => 0
            }
            
            metrics['distribution_stats'][dist_id]['total_bids'] += 1
            if bid.status == 'accepted'
              metrics['distribution_stats'][dist_id]['accepted_bids'] += 1
              dist_accepted = metrics['distribution_stats'][dist_id]['accepted_bids']
              dist_total = metrics['distribution_stats'][dist_id]['total_bids']
              metrics['distribution_stats'][dist_id]['acceptance_rate'] = (dist_accepted.to_f / dist_total * 100).round(2)
              
              current_avg = metrics['distribution_stats'][dist_id]['avg_amount'].to_f
              new_total = current_avg * (dist_accepted - 1) + bid.amount.to_f
              metrics['distribution_stats'][dist_id]['avg_amount'] = (new_total / dist_accepted).round(2)
            end
          end
          
          snapshot.metrics = metrics
          snapshot.save!
        end
      end
    end
  end
end

puts "Source performance seed data created successfully!"