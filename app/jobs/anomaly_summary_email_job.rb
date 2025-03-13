class AnomalySummaryEmailJob < ApplicationJob
  queue_as :default

  def perform(date = Date.yesterday)
    # Process each account
    Account.find_each do |account|
      # Skip accounts with no anomalies for the date
      next unless account.anomaly_detections.where(detected_at: date.beginning_of_day..date.end_of_day).exists?
      
      # Find users with anomaly email preferences enabled
      users = account.users.select do |user|
        user.preferences.dig("notifications", "anomalies", "summary_email") == true
      end
      
      # Send email to each user
      users.each do |user|
        AnomalyMailer.anomaly_summary_email(user, date).deliver_later
      end
    end
  end
end