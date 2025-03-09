class GenerateBidAnalyticsJob < ApplicationJob
  queue_as :analytics

  # Generate bid analytics for all accounts
  # Options:
  # - period_type: :hourly, :daily, :weekly, :monthly
  # - for_date: The date to generate analytics for (defaults to previous period)
  # - account_id: Optional account ID to limit processing to a single account
  # - campaign_id: Optional campaign ID to limit processing
  # - distribution_id: Optional distribution ID to limit processing
  def perform(options = {})
    period_type = options[:period_type]&.to_sym || :daily
    
    # Set default date based on period type
    for_date = options[:for_date]
    if for_date.nil?
      for_date = case period_type
                 when :hourly then Time.current - 1.hour
                 when :daily then Date.yesterday
                 when :weekly then Date.current.prev_week
                 when :monthly then Date.current.prev_month
                 else Date.yesterday
                 end
    end
    
    # Get accounts to process
    accounts = if options[:account_id]
                 Account.where(id: options[:account_id])
               else
                 Account.all
               end
    
    # Generate snapshots for each account
    accounts.find_each do |account|
      ActsAsTenant.with_tenant(account) do
        generate_account_analytics(account, period_type, for_date, options)
      end
    end
  end
  
  private
  
  def generate_account_analytics(account, period_type, for_date, options = {})
    # Generate the overall account snapshot
    snapshot = case period_type
               when :hourly
                 BidAnalyticSnapshot.generate_hourly_snapshot(account, for_date)
               when :daily
                 BidAnalyticSnapshot.generate_daily_snapshot(account, for_date)
               when :weekly
                 BidAnalyticSnapshot.generate_weekly_snapshot(account, for_date)
               when :monthly
                 BidAnalyticSnapshot.generate_monthly_snapshot(account, for_date)
               end
    
    # Generate campaign-specific snapshots if requested
    if options[:campaign_id]
      generate_campaign_snapshot(account, period_type, for_date, options[:campaign_id])
    elsif options[:all_campaigns]
      account.campaigns.find_each do |campaign|
        generate_campaign_snapshot(account, period_type, for_date, campaign.id)
      end
    end
    
    # Generate distribution-specific snapshots if requested
    if options[:distribution_id]
      generate_distribution_snapshot(account, period_type, for_date, options[:distribution_id])
    elsif options[:all_distributions]
      account.distributions.find_each do |distribution|
        generate_distribution_snapshot(account, period_type, for_date, distribution.id)
      end
    end
    
    snapshot
  end
  
  def generate_campaign_snapshot(account, period_type, for_date, campaign_id)
    case period_type
    when :hourly
      end_time = for_date.is_a?(Date) ? for_date.end_of_day : for_date
      start_time = end_time - 1.hour
      BidAnalyticSnapshot.generate_snapshot(account, start_time, end_time, :hourly, campaign_id)
    when :daily
      end_time = for_date.end_of_day
      start_time = for_date.beginning_of_day
      BidAnalyticSnapshot.generate_snapshot(account, start_time, end_time, :daily, campaign_id)
    when :weekly
      end_time = for_date.end_of_week.end_of_day
      start_time = for_date.beginning_of_week.beginning_of_day
      BidAnalyticSnapshot.generate_snapshot(account, start_time, end_time, :weekly, campaign_id)
    when :monthly
      end_time = for_date.end_of_month.end_of_day
      start_time = for_date.beginning_of_month.beginning_of_day
      BidAnalyticSnapshot.generate_snapshot(account, start_time, end_time, :monthly, campaign_id)
    end
  end
  
  def generate_distribution_snapshot(account, period_type, for_date, distribution_id)
    case period_type
    when :hourly
      end_time = for_date.is_a?(Date) ? for_date.end_of_day : for_date
      start_time = end_time - 1.hour
      BidAnalyticSnapshot.generate_snapshot(account, start_time, end_time, :hourly, nil, distribution_id)
    when :daily
      end_time = for_date.end_of_day
      start_time = for_date.beginning_of_day
      BidAnalyticSnapshot.generate_snapshot(account, start_time, end_time, :daily, nil, distribution_id)
    when :weekly
      end_time = for_date.end_of_week.end_of_day
      start_time = for_date.beginning_of_week.beginning_of_day
      BidAnalyticSnapshot.generate_snapshot(account, start_time, end_time, :weekly, nil, distribution_id)
    when :monthly
      end_time = for_date.end_of_month.end_of_day
      start_time = for_date.beginning_of_month.beginning_of_day
      BidAnalyticSnapshot.generate_snapshot(account, start_time, end_time, :monthly, nil, distribution_id)
    end
  end
end
