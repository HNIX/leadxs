class AnomalyNotification < Noticed::Base
  deliver_by :database
  deliver_by :email, mailer: "AnomalyMailer", method: :anomaly_detected_email, if: :email_notifications_enabled?
  
  param :anomaly_id
  param :summary
  param :severity
  param :metric
  param :detected_at
  
  def message
    "#{params[:severity].upcase}: #{params[:summary]}"
  end
  
  def url
    if params[:anomaly_id].present?
      anomaly_detection_path(AnomalyDetection.find(params[:anomaly_id]))
    else
      anomaly_detections_path
    end
  end
  
  def email_notifications_enabled?
    recipient.preferences.dig("notifications", "anomalies", "email_enabled") == true || 
    (params[:severity] == "critical" && recipient.preferences.dig("notifications", "anomalies", "critical_email") == true)
  end
end