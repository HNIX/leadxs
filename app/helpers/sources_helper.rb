module SourcesHelper
  def source_status_badge(status)
    case status
    when 'active'
      content_tag(:span, 'Active', class: 'px-2 py-1 text-xs rounded-full bg-green-100 text-green-800')
    when 'paused'
      content_tag(:span, 'Paused', class: 'px-2 py-1 text-xs rounded-full bg-yellow-100 text-yellow-800')
    when 'archived'
      content_tag(:span, 'Archived', class: 'px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-800')
    else
      content_tag(:span, status.titleize, class: 'px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-800')
    end
  end

  def source_integration_type_badge(type)
    case type
    when 'affiliate'
      content_tag(:span, 'Affiliate', class: 'px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800')
    when 'web_form'
      content_tag(:span, 'Web Form', class: 'px-2 py-1 text-xs rounded-full bg-purple-100 text-purple-800')
    else
      content_tag(:span, type.titleize, class: 'px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-800')
    end
  end
end