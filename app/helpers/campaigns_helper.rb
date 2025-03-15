module CampaignsHelper
  # Generate breadcrumbs for the campaign index page
  def campaigns_index_breadcrumbs
    content_for :breadcrumbs do
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: [
          { title: "Home", path: root_path },
          { title: "Campaigns", path: campaigns_path, active: true }
        ]
      }
    end
  end
  
  # Generate breadcrumbs for the campaign show page
  def campaign_show_breadcrumbs(campaign, options = {})
    content_for :breadcrumbs do
      is_configure = options[:is_configure] || false
      
      breadcrumbs = [
        { title: "Home", path: root_path },
        { title: "Campaigns", path: campaigns_path }
      ]
      
      if is_configure
        breadcrumbs << { title: campaign.name, path: campaign_path(campaign) }
        breadcrumbs << { title: "Configure", active: true }
      else
        breadcrumbs << { title: campaign.name, path: campaign_path(campaign), active: true }
      end
      
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: breadcrumbs
      }
    end
  end
  
  # Generate breadcrumbs for the campaign edit page
  def campaign_edit_breadcrumbs(campaign)
    content_for :breadcrumbs do
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: [
          { title: "Home", path: root_path },
          { title: "Campaigns", path: campaigns_path },
          { title: campaign.name, path: campaign_path(campaign) },
          { title: "Edit", active: true }
        ]
      }
    end
  end
  
  # Generate breadcrumbs for the campaign API documentation page
  def campaign_api_documentation_breadcrumbs(campaign)
    content_for :breadcrumbs do
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: [
          { title: "Home", path: root_path },
          { title: "Campaigns", path: campaigns_path },
          { title: campaign.name, path: campaign_path(campaign) },
          { title: "API Documentation", active: true }
        ]
      }
    end
  end
  
  # Generate breadcrumbs for the campaign new page
  def campaign_new_breadcrumbs
    content_for :breadcrumbs do
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: [
          { title: "Home", path: root_path },
          { title: "Campaigns", path: campaigns_path },
          { title: "New", active: true }
        ]
      }
    end
  end
  
  # Render a context header for the page
  def render_context_header(options = {})
    content_for :context_header do
      render partial: "shared/context_header", locals: {
        title: options[:title],
        subtitle: options[:subtitle],
        actions: options[:actions],
        stats: options[:stats],
        tags: options[:tags]
      }
    end
  end
  
  # Calculate campaign complexity
  def campaign_complexity(campaign)
    # Base score is 1
    score = 1
    
    # Add score for each component
    score += 0.5 if campaign.campaign_fields.count > 5
    score += 0.5 if campaign.campaign_fields.count > 10
    score += 0.5 if campaign.validation_rules.exists?
    score += 0.5 if campaign.calculated_fields.exists?
    score += 0.5 if campaign.sources.count > 2
    score += 0.5 if campaign.distributions.count > 2
    score += 1 if campaign.use_bidding_system?
    
    # Return complexity level
    case score
    when 0..1.5
      { level: "simple", label: "Simple", color: "bg-green-100 text-green-800 dark:bg-green-800 dark:text-green-100" }
    when 1.6..3
      { level: "moderate", label: "Moderate", color: "bg-blue-100 text-blue-800 dark:bg-blue-800 dark:text-blue-100" }
    when 3.1..4.5
      { level: "complex", label: "Complex", color: "bg-orange-100 text-orange-800 dark:bg-orange-800 dark:text-orange-100" }
    else
      { level: "advanced", label: "Advanced", color: "bg-purple-100 text-purple-800 dark:bg-purple-800 dark:text-purple-100" }
    end
  end
  
  # Get campaign stats for display
  def campaign_stats(campaign)
    [
      { 
        label: "Fields", 
        value: campaign.campaign_fields.count,
        icon: <<-SVG
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
          </svg>
        SVG
      },
      { 
        label: "Sources", 
        value: campaign.sources.count,
        icon: <<-SVG
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
          </svg>
        SVG
      },
      { 
        label: "Distributions", 
        value: campaign.distributions.count,
        icon: <<-SVG
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
          </svg>
        SVG
      }
    ]
  end
end
