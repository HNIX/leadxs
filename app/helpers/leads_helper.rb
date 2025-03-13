module LeadsHelper
  # Returns appropriate CSS classes for status badges
  def lead_status_badge_class(status, status_type = 'lead')
    base_classes = "px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full"
    
    case status_type
    when 'lead'
      case status.to_s
      when "distributed"
        "#{base_classes} bg-green-100 text-green-800 dark:bg-green-800 dark:text-green-100"
      when "new_lead"
        "#{base_classes} bg-blue-100 text-blue-800 dark:bg-blue-800 dark:text-blue-100"
      when "processing"
        "#{base_classes} bg-yellow-100 text-yellow-800 dark:bg-yellow-800 dark:text-yellow-100"
      when "distributing"
        "#{base_classes} bg-indigo-100 text-indigo-800 dark:bg-indigo-800 dark:text-indigo-100"
      when "rejected"
        "#{base_classes} bg-gray-100 text-gray-800 dark:bg-gray-600 dark:text-gray-100"
      when "error"
        "#{base_classes} bg-red-100 text-red-800 dark:bg-red-800 dark:text-red-100"
      else
        "#{base_classes} bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200"
      end
    when 'bid'
      case status.to_s
      when "pending"
        "#{base_classes} bg-gray-100 text-gray-800 dark:bg-gray-600 dark:text-gray-100"
      when "active"
        "#{base_classes} bg-yellow-100 text-yellow-800 dark:bg-yellow-800 dark:text-yellow-100"
      when "completed"
        "#{base_classes} bg-green-100 text-green-800 dark:bg-green-800 dark:text-green-100"
      when "expired"
        "#{base_classes} bg-red-100 text-red-800 dark:bg-red-800 dark:text-red-100"
      when "canceled"
        "#{base_classes} bg-gray-100 text-gray-800 dark:bg-gray-600 dark:text-gray-100"
      else
        "#{base_classes} bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200"
      end
    when 'api'
      if status.to_i >= 200 && status.to_i < 300
        "#{base_classes} bg-green-100 text-green-800 dark:bg-green-800 dark:text-green-100"
      else
        "#{base_classes} bg-red-100 text-red-800 dark:bg-red-800 dark:text-red-100"
      end
    else
      "#{base_classes} bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200"
    end
  end
end