module BidDashboardHelper
  # Generate breadcrumbs for bid dashboard pages
  def bid_dashboard_breadcrumbs(options = {})
    content_for :breadcrumbs do
      breadcrumbs = [
        { title: "Home", path: root_path },
        { title: "Bidding", path: bid_dashboard_path }
      ]
      
      if options[:campaign].present?
        breadcrumbs << { title: options[:campaign].name, path: campaign_path(options[:campaign]) }
      end
      
      dashboard_type = options[:dashboard_type] || "Dashboard"
      
      if options[:is_real_time]
        breadcrumbs << { title: "Real-time Dashboard", active: true }
      else
        breadcrumbs << { title: dashboard_type, active: true }
      end
      
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: breadcrumbs
      }
    end
  end
  
  # Generate a title for the dashboard that includes the campaign name if present
  def generate_dashboard_title(options = {})
    base_title = options[:is_real_time] ? "Real-time Bid Dashboard" : "Bid Dashboard"
    
    if options[:campaign].present?
      "#{base_title} for #{options[:campaign].name}"
    else
      base_title
    end
  end
end