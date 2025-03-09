module BidsHelper
  def bid_status_class(bid)
    base_class = "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
    
    case bid.status
    when "pending"
      "#{base_class} bg-yellow-100 text-yellow-800"
    when "accepted"
      "#{base_class} bg-green-100 text-green-800"
    when "rejected"
      "#{base_class} bg-red-100 text-red-800"
    when "expired"
      "#{base_class} bg-gray-100 text-gray-800"
    when "error"
      "#{base_class} bg-red-100 text-red-800"
    else
      "#{base_class} bg-gray-100 text-gray-800"
    end
  end
end