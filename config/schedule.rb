# Use this file to easily define all of your cron jobs.
# https://github.com/javan/whenever
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Bid Analytics Jobs

# Hourly analytics - generate hourly snapshots
every 1.hour do
  runner "GenerateBidAnalyticsJob.perform_later(period_type: :hourly)"
end

# Daily analytics - run every day at 1:00 AM
every 1.day, at: '1:00 am' do
  runner "GenerateBidAnalyticsJob.perform_later(period_type: :daily, all_campaigns: true, all_distributions: true)"
end

# Weekly analytics - run every Monday at 2:00 AM
every :monday, at: '2:00 am' do
  runner "GenerateBidAnalyticsJob.perform_later(period_type: :weekly, all_campaigns: true, all_distributions: true)"
end

# Monthly analytics - run on the 1st of every month at 3:00 AM
every '0 3 1 * *' do
  runner "GenerateBidAnalyticsJob.perform_later(period_type: :monthly, all_campaigns: true, all_distributions: true)"
end

# Anomaly Detection Jobs

# Run anomaly detection every hour
every 1.hour do
  runner "AnomalyDetectionJob.perform_later"
end

# Send daily anomaly summary emails at 7:00 AM
every 1.day, at: '7:00 am' do
  runner "AnomalySummaryEmailJob.perform_later"
end
