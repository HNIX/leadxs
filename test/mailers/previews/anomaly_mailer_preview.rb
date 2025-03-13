# Preview all emails at http://localhost:3000/rails/mailers/anomaly_mailer
class AnomalyMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/anomaly_mailer/anomaly_detected_email
  def anomaly_detected_email
    AnomalyMailer.anomaly_detected_email
  end

  # Preview this email at http://localhost:3000/rails/mailers/anomaly_mailer/anomaly_summary_email
  def anomaly_summary_email
    AnomalyMailer.anomaly_summary_email
  end
end
