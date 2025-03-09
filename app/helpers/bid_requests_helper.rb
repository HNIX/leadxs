module BidRequestsHelper
  def bid_request_status_class(bid_request)
    base_class = "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
    
    case bid_request.status
    when "pending"
      "#{base_class} bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300"
    when "active"
      "#{base_class} bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"
    when "completed"
      "#{base_class} bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300"
    when "expired"
      "#{base_class} bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
    when "canceled"
      "#{base_class} bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300"
    else
      "#{base_class} bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
    end
  end
end