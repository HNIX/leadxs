class DistributionFilter < Filter
  acts_as_tenant :account
  
  # Distribution-specific associations
  has_many :distribution_filter_assignments, dependent: :destroy
  has_many :distributions, through: :distribution_filter_assignments
  
  # Distribution-specific validations
  validates :apply_to_all, inclusion: { in: [true, false] }
  validate :validate_distributions_if_not_apply_to_all
  
  # Determine if this filter applies to a specific distribution
  def applies_to?(distribution)
    return true if apply_to_all
    distributions.include?(distribution)
  end
  
  # Class method to filter distributions based on lead data
  def self.filter_distributions(distributions, lead_data, campaign)
    Rails.logger.info("DistributionFilter.filter_distributions called for campaign #{campaign.id} with #{distributions.count} distributions")
    
    # Get all active filters for the campaign
    filters = DistributionFilter.where(campaign: campaign, status: 'active')
    Rails.logger.info("Found #{filters.count} active distribution filters for campaign #{campaign.id}")
    
    # Filter distributions
    eligible_distributions = distributions.select do |distribution|
      # Get filters that apply to this distribution
      applicable_filters = filters.select { |filter| filter.applies_to?(distribution) }
      Rails.logger.debug("Distribution #{distribution.id} has #{applicable_filters.count} applicable filters")
      
      # If no filters, distribution passes by default
      if applicable_filters.empty?
        Rails.logger.debug("Distribution #{distribution.id} passes by default (no applicable filters)")
        true
      else
        # Check if all filters pass
        passes_all = applicable_filters.all? { |filter| filter.passes?(lead_data) }
        
        # Log results for debugging
        if passes_all
          Rails.logger.debug("Distribution #{distribution.id} passes all #{applicable_filters.count} filters")
        else
          failing_filters = applicable_filters.reject { |filter| filter.passes?(lead_data) }
          Rails.logger.debug("Distribution #{distribution.id} fails #{failing_filters.count} filters: #{failing_filters.map(&:id).join(', ')}")
        end
        
        passes_all
      end
    end
    
    Rails.logger.info("After filtering, #{eligible_distributions.count} of #{distributions.count} distributions are eligible")
    eligible_distributions
  end
  
  private
  
  def validate_distributions_if_not_apply_to_all
    if !apply_to_all && distributions.empty?
      errors.add(:distributions, "must be selected if not applying to all distributions")
    end
  end
end