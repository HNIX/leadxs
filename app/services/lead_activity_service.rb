class LeadActivityService
  class << self
    # Record a lead submission activity
    def record_submission(lead, details = {})
      record_activity(lead, :submission, details)
    end
    
    # Record data validation activity
    def record_validation(lead, details = {})
      record_activity(lead, :validation, details)
    end
    
    # Record data anonymization for bidding
    def record_anonymization(lead, details = {})
      record_activity(lead, :anonymization, details)
    end
    
    # Record bid request created
    def record_bid_request(lead, bid_request, details = {})
      details[:bid_request_id] = bid_request.id
      details[:causer_type] = 'BidRequest'
      details[:causer_id] = bid_request.id
      record_activity(lead, :bid_request, details)
    end
    
    # Record bid received from buyer
    def record_bid_received(lead, bid, details = {})
      details[:bid_id] = bid.id
      details[:buyer_id] = bid.distribution_id if bid.respond_to?(:distribution_id)
      details[:buyer_name] ||= bid.distribution.name if bid.respond_to?(:distribution) && bid.distribution
      details[:amount] = bid.amount
      details[:causer_type] = 'Bid'
      details[:causer_id] = bid.id
      record_activity(lead, :bid_received, details)
    end
    
    # Record winning bid selected
    def record_bid_selected(lead, bid, details = {})
      details[:bid_id] = bid.id
      details[:buyer_id] = bid.distribution_id if bid.respond_to?(:distribution_id)
      details[:buyer_name] ||= bid.distribution.name if bid.respond_to?(:distribution) && bid.distribution
      details[:amount] = bid.amount
      details[:causer_type] = 'Bid'
      details[:causer_id] = bid.id
      record_activity(lead, :bid_selected, details)
    end
    
    # Record consent requested for specific buyer
    def record_consent_requested(lead, buyer, details = {})
      details[:buyer_id] = buyer.id
      details[:buyer_name] = buyer.name
      details[:causer_type] = buyer.class.name
      details[:causer_id] = buyer.id
      record_activity(lead, :consent_requested, details)
    end
    
    # Record consent provided by lead
    def record_consent_provided(lead, consent_record, details = {})
      details[:consent_record_id] = consent_record.id
      details[:consent_type] = consent_record.consent_type
      details[:causer_type] = 'ConsentRecord'
      details[:causer_id] = consent_record.id
      record_activity(lead, :consent_provided, details)
    end
    
    # Record lead distribution to buyer
    def record_distribution(lead, distribution, details = {})
      details[:distribution_id] = distribution.id if distribution.respond_to?(:id)
      details[:buyer_id] = details[:distribution_id] if details[:distribution_id]
      details[:buyer_name] ||= distribution.distribution.name if distribution.respond_to?(:distribution) && distribution.distribution 
      details[:causer_type] = distribution.class.name
      details[:causer_id] = distribution.id if distribution.respond_to?(:id)
      record_activity(lead, :distribution, details)
    end
    
    # Record response received from buyer
    def record_buyer_response(lead, api_request, details = {})
      details[:distribution_id] = api_request.id if api_request.respond_to?(:id)
      details[:buyer_id] = details[:distribution_id] if details[:distribution_id]
      details[:response_status] = details[:response_status] || (api_request.response_code && api_request.response_code < 300 ? 'accepted' : 'rejected')
      details[:causer_type] = api_request.class.name
      details[:causer_id] = api_request.id if api_request.respond_to?(:id)
      record_activity(lead, :buyer_response, details)
    end
    
    # Record lead status update
    def record_status_update(lead, old_status, new_status, details = {})
      details[:old_status] = old_status
      details[:new_status] = new_status
      record_activity(lead, :status_update, details)
    end
    
    # Record data access
    def record_data_access(lead, user, details = {})
      details[:access_type] = details[:access_type] || 'view'
      details[:fields_accessed] = details[:fields_accessed] || 'all'
      details[:causer_type] = 'User'
      details[:causer_id] = user.id
      record_activity(lead, :data_access, details.merge(user: user))
    end
    
    private
    
    def record_activity(lead, activity_type, details = {})
      user = details.delete(:user)
      user ||= Current.user if defined?(Current) && Current.respond_to?(:user)
      request = Current.request if defined?(Current) && Current.respond_to?(:request)
      
      LeadActivityLog.record(lead, activity_type, details, user, request)
    end
  end
end