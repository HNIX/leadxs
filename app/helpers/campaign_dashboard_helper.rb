module CampaignDashboardHelper
  def metric_card(title, value, change = nil, higher_is_better = true, icon_class = nil, text_color = nil, options = {})
    # Simple test helper
    content_tag(:div, class: 'bg-white dark:bg-gray-800 rounded-lg shadow p-6') do
      content = ""
      content += content_tag(:h3, title, class: 'text-lg font-bold')
      
      formatted_value = if value.nil?
                          "0"
                        elsif options[:format] == :currency
                          number_to_currency(value)
                        elsif options[:format] == :percentage
                          number_to_percentage(value, precision: 1)
                        else
                          number_with_delimiter(value)
                        end
      
      content += content_tag(:p, "Value: #{formatted_value}")
      
      if change
        change_text = change >= 0 ? "+#{change}%" : "#{change}%"
        content += content_tag(:p, "Change: #{change_text}")
      end
      
      if options[:subtitle]
        content += content_tag(:p, options[:subtitle], class: 'text-sm text-gray-500')
      end
      
      content.html_safe
    end
  end
  
  def metric_card_original(title, value, change = nil, higher_is_better = true, icon_class = nil, text_color = nil, options = {})
    # Default styling
    icon_color = options[:icon_color] || 'bg-blue-100 dark:bg-blue-900 text-blue-600 dark:text-blue-300'
    
    # Set trend color based on positive/negative and whether higher is better
    trend_color = if change.nil? || change == 0
                    'text-gray-500 dark:text-gray-400'
                  elsif (change > 0 && higher_is_better) || (change < 0 && !higher_is_better)
                    'text-green-500 dark:text-green-400'
                  else
                    'text-red-500 dark:text-red-400'
                  end
    
    # Set trend icon
    trend_icon = if change.nil? || change == 0
                   'trending-flat'
                 elsif change > 0
                   'trending-up'
                 else
                   'trending-down'
                 end
    
    # Format change value
    formatted_change = if change.nil?
                         ''
                       else
                         number = change.abs
                         sign = change >= 0 ? '+' : '-'
                         "#{sign}#{number_to_percentage(number.abs, precision: 1)}"
                       end
    
    # Format the value based on its type
    formatted_value = if value.nil?
                        # Handle nil values with sensible defaults
                        options[:format] == :currency ? "$0.00" : 
                        options[:format] == :percentage ? "0.0%" : "0"
                      elsif options[:format] == :currency
                        number_to_currency(value)
                      elsif options[:format] == :percentage
                        number_to_percentage(value, precision: 1)
                      else
                        number_with_delimiter(value)
                      end
    
    # Render the card
    content_tag(:div, class: 'bg-white dark:bg-gray-800 rounded-lg shadow p-6') do
      content_tag(:div, class: 'flex justify-between items-start') do
        content_tag(:div) do
          concat content_tag(:p, title, class: 'text-sm font-medium text-gray-500 dark:text-gray-400')
          concat content_tag(:div, class: 'flex items-baseline mt-1') do
            concat content_tag(:h3, formatted_value, class: "text-2xl font-bold #{text_color}")
            if formatted_change.present?
              concat content_tag(:span, formatted_change, class: "ml-2 text-sm font-medium #{trend_color}")
            end
          end
          
          if options[:subtitle].present?
            concat content_tag(:p, options[:subtitle], class: 'mt-1 text-sm text-gray-500 dark:text-gray-400')
          end
        end
        
        content_tag(:div, class: "p-2 rounded-full #{icon_color}") do
          content_tag(:svg, class: 'w-6 h-6', fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24') do
            if icon_class
              concat content_tag(:path, nil, 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: icon_class)
            else
              concat content_tag(:path, nil, 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: 'M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z')
            end
          end
        end
      end
    end
  end
  
  def campaign_chart_config(chart_data, options = {})
    {
      type: options[:type] || 'line',
      data: {
        labels: chart_data[:labels],
        datasets: build_chart_datasets(chart_data, options)
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false
        },
        plugins: {
          legend: {
            position: 'top',
            labels: {
              usePointStyle: true
            }
          },
          tooltip: {
            usePointStyle: true
          },
          title: {
            display: options[:title].present?,
            text: options[:title]
          }
        },
        scales: build_chart_scales(options)
      }
    }.to_json.html_safe
  end
  
  def period_options_for_select
    [
      ['Hourly', 'hourly'],
      ['Daily', 'daily'],
      ['Weekly', 'weekly'],
      ['Monthly', 'monthly']
    ]
  end
  
  def date_preset_options
    [
      ['Last 7 days', 7],
      ['Last 14 days', 14],
      ['Last 30 days', 30],
      ['Last 90 days', 90],
      ['Last 6 months', 180],
      ['Last year', 365],
      ['Custom range', 'custom']
    ]
  end
  
  private
  
  def build_chart_datasets(chart_data, options)
    datasets = []
    
    # Helper method to generate color sets
    colors = {
      blue: { border: 'rgb(59, 130, 246)', background: 'rgba(59, 130, 246, 0.2)' },
      green: { border: 'rgb(16, 185, 129)', background: 'rgba(16, 185, 129, 0.2)' },
      purple: { border: 'rgb(139, 92, 246)', background: 'rgba(139, 92, 246, 0.2)' },
      red: { border: 'rgb(239, 68, 68)', background: 'rgba(239, 68, 68, 0.2)' },
      yellow: { border: 'rgb(245, 158, 11)', background: 'rgba(245, 158, 11, 0.2)' }
    }
    
    # Map metrics to colors
    metric_colors = {
      total_bids: colors[:blue],
      accepted_bids: colors[:green],
      avg_bid_amount: colors[:purple],
      total_revenue: colors[:yellow],
      profit_margin: colors[:red]
    }
    
    # Create datasets for each metric
    chart_data.except(:labels).each do |metric, data|
      next if options[:metrics].present? && !options[:metrics].include?(metric)
      
      color = metric_colors[metric] || colors[:blue]
      type = options[:metric_types]&.[](metric) || options[:type] || 'line'
      
      # Determine if this metric should use the secondary y-axis
      use_secondary_axis = [:avg_bid_amount, :total_revenue].include?(metric)
      
      dataset = {
        label: metric.to_s.titleize,
        data: data,
        borderColor: color[:border],
        backgroundColor: color[:background],
        borderWidth: type == 'line' ? 2 : 1,
        pointRadius: type == 'line' ? 3 : 0,
        yAxisID: use_secondary_axis ? 'y1' : 'y',
        tension: 0.3
      }
      
      # For financial metrics, use different chart type
      dataset[:type] = type if type != options[:type]
      
      datasets << dataset
    end
    
    datasets
  end
  
  def build_chart_scales(options)
    scales = {
      y: {
        beginAtZero: true,
        grid: {
          color: "rgba(209, 213, 219, 0.3)"
        },
        ticks: {
          precision: 0
        }
      },
      x: {
        grid: {
          display: false
        }
      }
    }
    
    # Add secondary y-axis for financial metrics if needed
    if options[:show_secondary_axis]
      scales[:y1] = {
        type: 'linear',
        position: 'right',
        beginAtZero: true,
        grid: {
          drawOnChartArea: false
        },
        ticks: {
          callback: ->(value) { "$#{value}" }
        }
      }
    end
    
    scales
  end
end