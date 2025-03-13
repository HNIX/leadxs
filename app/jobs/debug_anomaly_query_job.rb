class DebugAnomalyQueryJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.info "Checking problematic queries"
    
    Account.first.tap do |account|
      ActsAsTenant.with_tenant(account) do
        begin
          Rails.logger.info "Testing query 1"
          # Test the query that might be causing the issue
          result = AnomalyDetection
                      .where(detected_at: 30.days.ago..Time.current)
                      .group(:metric)
                      .order("detected_at DESC")
                      .count
          Rails.logger.info "Query 1 succeeded: #{result.inspect}"
        rescue => e
          Rails.logger.error "Query 1 error: #{e.message}"
        end
        
        begin
          Rails.logger.info "Testing query 2"
          # Try a different approach - sorting after the group operation
          counts = AnomalyDetection
                      .where(detected_at: 30.days.ago..Time.current)
                      .group(:metric)
                      .count
          Rails.logger.info "Query 2 succeeded: #{counts.inspect}"
        rescue => e
          Rails.logger.error "Query 2 error: #{e.message}"
        end

        begin
          Rails.logger.info "Testing anomalies by metric query"
          anomalies_by_metric = AnomalyDetection
                                .where(detected_at: 30.days.ago..Time.current)
                                .group(:metric)
                                .count
          Rails.logger.info "Anomalies by metric: #{anomalies_by_metric.inspect}"
        rescue => e
          Rails.logger.error "Anomalies by metric error: #{e.message}"
        end
      end
    end
  end
end