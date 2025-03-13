class AnomalyDetectionJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Process each account that has active anomaly thresholds
    Account.find_each do |account|
      # Skip accounts with no active thresholds
      next unless account.anomaly_thresholds.active.exists?
      
      # Set current account for tenant context
      ActsAsTenant.with_tenant(account) do
        # Run anomaly detection
        service = AnomalyDetectionService.new(account)
        results = service.detect_anomalies!
        
        # Log results
        if results[:detected].any?
          Rails.logger.info "Detected #{results[:detected].count} anomalies for account #{account.id}"
        end
        
        if results[:errors].any?
          Rails.logger.error "Errors during anomaly detection for account #{account.id}: #{results[:errors].inspect}"
        end
      end
    end
  end
end