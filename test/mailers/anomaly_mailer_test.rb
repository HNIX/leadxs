require "test_helper"

class AnomalyMailerTest < ActionMailer::TestCase
  test "anomaly_detected_email" do
    mail = AnomalyMailer.anomaly_detected_email
    assert_equal "Anomaly detected email", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end

  test "anomaly_summary_email" do
    mail = AnomalyMailer.anomaly_summary_email
    assert_equal "Anomaly summary email", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
