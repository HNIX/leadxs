module BidReportsHelper
  # Generate the period options for the period selector
  def period_options
    [
      ['Hourly', 'hourly'],
      ['Daily', 'daily'],
      ['Weekly', 'weekly'],
      ['Monthly', 'monthly']
    ]
  end
  
  # Generate breadcrumbs for bid report pages
  def bid_report_breadcrumbs(options = {})
    content_for :breadcrumbs do
      breadcrumbs = [
        { title: "Home", path: root_path },
        { title: "Bidding", path: bid_dashboard_path }
      ]
      
      if options[:campaign].present?
        breadcrumbs << { title: options[:campaign].name, path: campaign_path(options[:campaign]) }
      end
      
      breadcrumbs << { title: options[:report_type].present? ? "#{options[:report_type].titleize} Report" : "Reports", path: options[:return_path] || bid_reports_path }
      
      if options[:detail].present?
        breadcrumbs << { title: options[:detail], active: true }
      end
      
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: breadcrumbs
      }
    end
  end
  
  # Generate a title for the report that includes the campaign name if present
  def generate_report_title(options = {})
    base_title = options[:report_type].present? ? "#{options[:report_type].titleize} Performance" : "Bid Performance"
    
    if options[:campaign].present?
      "#{base_title} for #{options[:campaign].name}"
    else
      base_title
    end
  end
  
  # Format the snapshot period for display
  def format_snapshot_period(snapshot)
    case snapshot.period_type
    when 'hourly'
      "#{snapshot.period_start.strftime('%b %d, %Y %H:%M')} - #{snapshot.period_end.strftime('%H:%M')}"
    when 'daily'
      snapshot.period_start.strftime('%b %d, %Y')
    when 'weekly'
      "Week of #{snapshot.period_start.strftime('%b %d, %Y')}"
    when 'monthly'
      snapshot.period_start.strftime('%B %Y')
    else
      "#{snapshot.period_start.strftime('%b %d, %Y')} - #{snapshot.period_end.strftime('%b %d, %Y')}"
    end
  end
  
  # Format a metric value based on its type
  def format_metric(metric, value)
    case metric
    when /rate$/
      "#{value.to_f.round(2)}%"
    when /amount/, /revenue/, /cost/, /price/
      number_to_currency(value)
    when /time/, /duration/, /latency/
      "#{value.to_f.round(2)} seconds"
    else
      number_with_delimiter(value)
    end
  end
  
  # Get CSS class for trend indicators
  def trend_class(value, higher_is_better = true)
    return '' if value.nil?
    
    if higher_is_better
      if value > 0
        'text-green-500'
      elsif value < 0
        'text-red-500'
      else
        'text-gray-500'
      end
    else
      if value < 0
        'text-green-500'
      elsif value > 0
        'text-red-500'
      else
        'text-gray-500'
      end
    end
  end
  
  # Format trend value with arrow
  def format_trend(value, higher_is_better = true)
    return '' if value.nil?
    
    arrow = if value > 0
              '↑'
            elsif value < 0
              '↓'
            else
              '→'
            end
    
    css_class = trend_class(value, higher_is_better)
    
    "<span class=\"#{css_class}\">#{arrow} #{value.abs.round(2)}%</span>".html_safe
  end
  
  # Generate Chart.js configuration
  def chart_config(chart_data, options = {})
    {
      type: options[:type] || 'line',
      data: {
        labels: chart_data[:labels],
        datasets: chart_datasets(chart_data, options)
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            position: 'top',
          },
          title: {
            display: options[:title].present?,
            text: options[:title]
          }
        }
      }
    }.to_json
  end
  
  private
  
  # Generate datasets for Chart.js
  def chart_datasets(chart_data, options)
    datasets = []
    
    if chart_data[:total_bids].present? && (options[:metrics].nil? || options[:metrics].include?(:total_bids))
      datasets << {
        label: 'Total Bids',
        data: chart_data[:total_bids],
        borderColor: 'rgb(54, 162, 235)',
        backgroundColor: 'rgba(54, 162, 235, 0.5)',
        yAxisID: 'y'
      }
    end
    
    if chart_data[:accepted_bids].present? && (options[:metrics].nil? || options[:metrics].include?(:accepted_bids))
      datasets << {
        label: 'Accepted Bids',
        data: chart_data[:accepted_bids],
        borderColor: 'rgb(75, 192, 192)',
        backgroundColor: 'rgba(75, 192, 192, 0.5)',
        yAxisID: 'y'
      }
    end
    
    if chart_data[:avg_bid_amount].present? && (options[:metrics].nil? || options[:metrics].include?(:avg_bid_amount))
      datasets << {
        label: 'Avg Bid Amount',
        data: chart_data[:avg_bid_amount],
        borderColor: 'rgb(153, 102, 255)',
        backgroundColor: 'rgba(153, 102, 255, 0.5)',
        yAxisID: 'y1'
      }
    end
    
    if chart_data[:total_revenue].present? && (options[:metrics].nil? || options[:metrics].include?(:total_revenue))
      datasets << {
        label: 'Total Revenue',
        data: chart_data[:total_revenue],
        borderColor: 'rgb(255, 99, 132)',
        backgroundColor: 'rgba(255, 99, 132, 0.5)',
        yAxisID: 'y1'
      }
    end
    
    datasets
  end
end
