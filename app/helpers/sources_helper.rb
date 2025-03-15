module SourcesHelper
  # Generate breadcrumbs for the sources index page
  def sources_index_breadcrumbs
    # Set up breadcrumbs based on context
    breadcrumbs = if @campaign.present?
      # Campaign context
      [
        { title: "Home", path: root_path },
        { title: "Campaigns", path: campaigns_path },
        { title: @campaign.name, path: campaign_path(@campaign) },
        { title: "Sources", path: nil }
      ]
    else
      # Global sources context
      [
        { title: "Home", path: root_path },
        { title: "Sources", path: nil }
      ]
    end
  
    # Render breadcrumbs partial with current context
    render partial: "shared/breadcrumbs", locals: { breadcrumbs: breadcrumbs }
  end
  
  # Generate breadcrumbs for the source show page
  def source_show_breadcrumbs(source, options = {})
    content_for :breadcrumbs do
      from_campaign = options[:from_campaign] || false
      
      breadcrumbs = if from_campaign
        # Coming from campaign context
        [
          { title: "Home", path: root_path },
          { title: "Campaigns", path: campaigns_path },
          { title: source.campaign.name, path: campaign_path(source.campaign) },
          { title: "Sources", path: campaign_sources_path(source.campaign) },
          { title: source.name, path: nil }
        ]
      else
        # Coming from global sources
        [
          { title: "Home", path: root_path },
          { title: "Sources", path: sources_path },
          { title: source.name, path: nil }
        ]
      end
      
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: breadcrumbs
      }
    end
  end
  
  # Generate breadcrumbs for the source edit page
  def source_edit_breadcrumbs(source, options = {})
    content_for :breadcrumbs do
      from_campaign = options[:from_campaign] || false
      
      breadcrumbs = if from_campaign
        # Coming from campaign context
        [
          { title: "Home", path: root_path },
          { title: "Campaigns", path: campaigns_path },
          { title: source.campaign.name, path: campaign_path(source.campaign) },
          { title: "Sources", path: campaign_sources_path(source.campaign) },
          { title: source.name, path: source_path(source, from_campaign: true) },
          { title: "Edit", path: nil }
        ]
      else
        # Coming from global sources
        [
          { title: "Home", path: root_path },
          { title: "Sources", path: sources_path },
          { title: source.name, path: source_path(source) },
          { title: "Edit", path: nil }
        ]
      end
      
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: breadcrumbs
      }
    end
  end
  
  # Generate breadcrumbs for the source new page
  def source_new_breadcrumbs(campaign = nil)
    content_for :breadcrumbs do
      breadcrumbs = if campaign.present?
        # Coming from campaign context
        [
          { title: "Home", path: root_path },
          { title: "Campaigns", path: campaigns_path },
          { title: campaign.name, path: campaign_path(campaign) },
          { title: "Sources", path: campaign_sources_path(campaign) },
          { title: "New Source", path: nil }
        ]
      else
        # Coming from global sources
        [
          { title: "Home", path: root_path },
          { title: "Sources", path: sources_path },
          { title: "New Source", path: nil }
        ]
      end
      
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: breadcrumbs
      }
    end
  end
  
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