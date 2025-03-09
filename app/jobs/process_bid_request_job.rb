class ProcessBidRequestJob < ApplicationJob
  queue_as :default

  def perform(bid_request_id)
    bid_request = BidRequest.find_by(id: bid_request_id)
    return unless bid_request
    
    # Set the current account for tenant scoping
    ActsAsTenant.with_tenant(bid_request.account) do
      # Skip if the bid request is already completed or expired
      return if bid_request.status.in?(['completed', 'expired'])
      
      # Check if expired
      bid_request.check_expiration!
      
      # Skip if still not expired (manual extension may have occurred)
      return unless bid_request.expired?
      
      # If there's a lead, process the winning bid and distribute
      if bid_request.lead.present?
        bid_request.complete_bidding_and_distribute!
      else
        # Just mark the winning bid as accepted if available
        winning_bid = bid_request.winning_bid
        winning_bid&.accept!
      end
    end
  end
end