module LeadActivitiesHelper
  # Returns appropriate icon for each activity type
  def activity_icon(activity)
    case activity.activity_type
    when "submission"
      '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>'.html_safe
    when "validation"
      '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"></path></svg>'.html_safe
    when "anonymization"
      '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path></svg>'.html_safe
    when "bid_request", "bid_received", "bid_selected"
      '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z"></path></svg>'.html_safe
    when "consent_requested", "consent_provided"
      '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path></svg>'.html_safe
    when "distribution"
      '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z"></path></svg>'.html_safe
    when "buyer_response"
      '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"></path></svg>'.html_safe
    when "status_update"
      '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path></svg>'.html_safe
    when "data_access"
      '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path></svg>'.html_safe
    else
      '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>'.html_safe
    end
  end
  
  # Returns appropriate badge for each activity type
  def activity_badge(activity)
    base_classes = "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
    
    case activity.activity_type
    when "submission"
      "#{base_classes} bg-blue-100 text-blue-800 dark:bg-blue-800 dark:text-blue-100"
    when "validation"
      "#{base_classes} bg-green-100 text-green-800 dark:bg-green-800 dark:text-green-100"
    when "anonymization"
      "#{base_classes} bg-purple-100 text-purple-800 dark:bg-purple-800 dark:text-purple-100"
    when "bid_request"
      "#{base_classes} bg-yellow-100 text-yellow-800 dark:bg-yellow-800 dark:text-yellow-100"
    when "bid_received"
      "#{base_classes} bg-yellow-100 text-yellow-800 dark:bg-yellow-800 dark:text-yellow-100"
    when "bid_selected"
      "#{base_classes} bg-indigo-100 text-indigo-800 dark:bg-indigo-800 dark:text-indigo-100"
    when "consent_requested"
      "#{base_classes} bg-cyan-100 text-cyan-800 dark:bg-cyan-800 dark:text-cyan-100"
    when "consent_provided"
      "#{base_classes} bg-teal-100 text-teal-800 dark:bg-teal-800 dark:text-teal-100"
    when "distribution"
      "#{base_classes} bg-pink-100 text-pink-800 dark:bg-pink-800 dark:text-pink-100"
    when "buyer_response"
      "#{base_classes} bg-orange-100 text-orange-800 dark:bg-orange-800 dark:text-orange-100"
    when "status_update"
      "#{base_classes} bg-amber-100 text-amber-800 dark:bg-amber-800 dark:text-amber-100"
    when "data_access"
      "#{base_classes} bg-red-100 text-red-800 dark:bg-red-800 dark:text-red-100"
    else
      "#{base_classes} bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
    end
  end
  
  # Returns a human-readable title for each activity type
  def activity_title(activity)
    case activity.activity_type
    when "submission"
      "Lead Submitted"
    when "validation"
      "Data Validated"
    when "anonymization"
      "Data Anonymized"
    when "bid_request"
      "Bid Request Created"
    when "bid_received"
      "Bid Received"
    when "bid_selected"
      "Winning Bid Selected"
    when "consent_requested"
      "Consent Requested"
    when "consent_provided"
      "Consent Provided"
    when "distribution"
      "Lead Distributed"
    when "buyer_response"
      "Buyer Response Received"
    when "status_update"
      "Status Updated"
    when "data_access"
      "Data Accessed"
    else
      activity.activity_type.titleize
    end
  end
  
  # Returns a description for the activity based on its content
  def activity_description(activity)
    case activity.activity_type
    when "submission"
      "Lead was submitted to the system."
    when "validation"
      validation_description(activity)
    when "anonymization"
      "PII was anonymized for bidding process."
    when "bid_request"
      "Bid request was created."
    when "bid_received"
      "Received bid of #{number_to_currency(activity.details['amount'])} from #{activity.details['buyer_name']}."
    when "bid_selected"
      "Selected winning bid of #{number_to_currency(activity.details['amount'])} from #{activity.details['buyer_name']}."
    when "consent_requested"
      "Requested consent for #{activity.details['buyer_name']}."
    when "consent_provided"
      "Consent was provided by the user."
    when "distribution"
      "Lead was distributed to #{activity.details['buyer_name']}."
    when "buyer_response"
      buyer_response_description(activity)
    when "status_update"
      "Status changed from #{activity.details['old_status']} to #{activity.details['new_status']}."
    when "data_access"
      "Data was accessed by #{activity.user&.name || 'System'}."
    else
      "Activity recorded."
    end
  end
  
  private
  
  def validation_description(activity)
    if activity.details['valid']
      "Lead data was validated successfully."
    else
      errors = activity.details['errors']
      if errors.present? && errors.size > 0
        "Validation failed: #{errors.join(', ')}."
      else
        "Validation failed."
      end
    end
  end
  
  def buyer_response_description(activity)
    status = activity.details['response_status']
    buyer = activity.details['buyer_name']
    
    case status
    when "accepted"
      "#{buyer} accepted the lead."
    when "rejected"
      reason = activity.details['rejection_reason'].presence || "No reason provided"
      "#{buyer} rejected the lead. Reason: #{reason}."
    when "error"
      error = activity.details['error_message'].presence || "Unknown error"
      "Error occurred while sending to #{buyer}: #{error}."
    when "timeout"
      "Request to #{buyer} timed out."
    else
      "Received response from #{buyer}."
    end
  end
end