class AnomalyMailer < ApplicationMailer
  # Send email notification about a detected anomaly
  def anomaly_detected_email(user, anomaly)
    @user = user
    @anomaly = anomaly
    @account = anomaly.account
    @threshold = anomaly.anomaly_threshold
    
    subject = if anomaly.severity == "critical"
                "🚨 CRITICAL ANOMALY DETECTED: #{anomaly.metric_name}"
              else
                "⚠️ Warning: Anomaly detected in #{anomaly.metric_name}"
              end
    
    mail(
      to: @user.email,
      subject: subject
    )
  end
  
  # Send a daily summary of anomalies
  def anomaly_summary_email(user, date = Date.yesterday)
    @user = user
    @account = user.accounts.first
    @date = date
    
    # Set tenant context
    ActsAsTenant.with_tenant(@account) do
      # Get anomalies for the date
      @anomalies = @account.anomaly_detections.where(
        detected_at: @date.beginning_of_day..@date.end_of_day
      ).order(severity: :desc, detected_at: :desc)
      
      # Only send if there are anomalies
      return if @anomalies.empty?
      
      # Stats for the email
      @stats = {
        total: @anomalies.count,
        critical: @anomalies.where(severity: :critical).count,
        warning: @anomalies.where(severity: :warning).count,
        resolved: @anomalies.where(status: :resolved).count,
        open: @anomalies.where.not(status: :resolved).count
      }
      
      # Top affected metrics
      @metrics = @anomalies.group(:metric).count.sort_by { |_, count| -count }.take(5)
      
      mail(
        to: @user.email,
        subject: "Daily Anomaly Report: #{@stats[:total]} anomalies detected on #{@date.strftime('%b %d, %Y')}"
      )
    end
  end
end