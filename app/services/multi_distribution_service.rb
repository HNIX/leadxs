# app/services/multi_distribution_service.rb
class MultiDistributionService
  attr_reader :lead, :campaign, :results
  
  def initialize(lead)
    @lead = lead
    @campaign = lead.campaign
    @results = {
      successful: [],
      failed: [],
      success: false,
      strategy: @campaign.multi_distribution_strategy,
      total_count: 0,
      success_count: 0,
      failure_count: 0
    }
  end
  
  # Main method to distribute lead based on campaign's multi-distribution strategy
  def distribute!
    # Get active distributions for this campaign
    distributions = active_distributions
    return no_distributions_result if distributions.empty?
    
    # Only use up to max_distributions
    distributions = limit_distributions(distributions)
    @results[:total_count] = distributions.count
    
    # Process based on strategy
    case @campaign.multi_distribution_strategy
    when 'single'
      process_single(distributions)
    when 'sequential'
      process_sequential(distributions)
    when 'parallel'
      process_parallel(distributions)
    else
      process_single(distributions) # Default to single if unknown strategy
    end
    
    # Update the lead status based on results
    update_lead_status
    
    # Return the distribution results
    @results
  end
  
  private
  
  # Get active distributions sorted by priority
  def active_distributions
    @campaign.campaign_distributions
             .joins(:distribution)
             .where(active: true)
             .where(distributions: { status: :active })
             .order(priority: :asc)
  end
  
  # Limit the number of distributions based on campaign settings
  def limit_distributions(distributions)
    max = @campaign.max_distributions || 1
    distributions.limit(max)
  end
  
  # Process for single distribution strategy (backward compatibility)
  def process_single(distributions)
    return no_distributions_result if distributions.empty?
    
    # Just use the first distribution
    distribution_service = LeadDistributionService.new(@lead)
    result = distribution_service.distribute_to_specific!(distributions.first)
    
    if result[:success]
      @results[:successful] << result
      @results[:success_count] += 1
    else
      @results[:failed] << result
      @results[:failure_count] += 1
    end
    
    @results[:success] = @results[:success_count] > 0
  end
  
  # Process for sequential distribution strategy
  def process_sequential(distributions)
    # Try each distribution in order until one succeeds or all fail
    distribution_service = LeadDistributionService.new(@lead)
    
    distributions.each do |campaign_distribution|
      result = distribution_service.distribute_to_specific!(campaign_distribution)
      
      if result[:success]
        @results[:successful] << result
        @results[:success_count] += 1
        
        # Stop after first success for sequential strategy
        break
      else
        @results[:failed] << result
        @results[:failure_count] += 1
      end
    end
    
    @results[:success] = @results[:success_count] > 0
  end
  
  # Process for parallel distribution strategy
  def process_parallel(distributions)
    # Send to all distributions simultaneously
    distribution_service = LeadDistributionService.new(@lead)
    
    # We're not actually using threads, but we process each distribution
    # regardless of whether others succeed or fail
    distributions.each do |campaign_distribution|
      result = distribution_service.distribute_to_specific!(campaign_distribution)
      
      if result[:success]
        @results[:successful] << result
        @results[:success_count] += 1
      else
        @results[:failed] << result
        @results[:failure_count] += 1
      end
    end
    
    # Consider successful if at least one distribution succeeded
    @results[:success] = @results[:success_count] > 0
  end
  
  # Update the lead status based on distribution results
  def update_lead_status
    if @results[:success]
      @lead.update(status: :distributed)
    else
      # Create an error message from all failed distributions
      error_messages = @results[:failed].map { |r| r[:error] }.compact.join("; ")
      @lead.update(status: :error, error_message: error_messages)
    end
  end
  
  # Result when no distributions are found
  def no_distributions_result
    @results[:success] = false
    @results[:message] = "No active distributions found"
    @lead.update(status: :error, error_message: "No active distributions found")
    @results
  end
end