class ProcessBidRequestJob < ApplicationJob
  queue_as :default
  
  # Retry with fixed delay for database/network issues
  retry_on ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, wait: 30.seconds, attempts: 3

  def perform(bid_request_id)
    # Find the bid request with a descriptive error if not found
    bid_request = BidRequest.find_by(id: bid_request_id)
    if bid_request.nil?
      Rails.logger.error("BidRequest not found in ProcessBidRequestJob: #{bid_request_id}")
      return
    end
    
    Rails.logger.info("Processing bid request completion for ##{bid_request_id}, status: #{bid_request.status}, bids: #{bid_request.bids.count}")
    
    # Set the current account for tenant scoping
    ActsAsTenant.with_tenant(bid_request.account) do
      # Skip if the bid request is already completed
      if bid_request.status == 'completed'
        Rails.logger.info("Skipping already completed bid request: #{bid_request_id}")
        return
      end
      
      # For active or pending requests, check if they've expired
      if bid_request.status.in?(['active', 'pending'])
        # Force expiration if time has passed
        bid_request.check_expiration!
      end
      
      # Process winning bid selection even if expired
      # This ensures we don't lose bids due to timing issues
      if bid_request.status == 'expired' || bid_request.technically_expired?
        Rails.logger.info("Processing expired bid request: #{bid_request_id}")
        
        # Get the winning bid
        winning_bid = bid_request.winning_bid
        
        if winning_bid.present?
          Rails.logger.info("Found winning bid ##{winning_bid.id} with amount #{winning_bid.amount}")
          
          # If there's a lead, process the winning bid and distribute
          if bid_request.lead.present?
            # Log the winning bid selection in the lead activity log
            Rails.logger.info("Recording winning bid selection activity for lead ##{bid_request.lead.id}")
            LeadActivityService.record_bid_selected(bid_request.lead, winning_bid)
            
            success = bid_request.complete_bidding_and_distribute!
            Rails.logger.info("Bid request completed and lead distributed: #{success}")
          else
            # Just mark the winning bid as accepted
            success = winning_bid.accept!
            Rails.logger.info("Winning bid accepted (no lead): #{success}")
          end
        else
          Rails.logger.info("No winning bid found for expired request: #{bid_request_id}")
          
          # Update the request status to ensure it's marked as expired
          bid_request.update(status: :expired) unless bid_request.expired?
        end
      else
        Rails.logger.info("Request in unexpected state, not processing: #{bid_request_id} (#{bid_request.status})")
      end
    end
  end
end