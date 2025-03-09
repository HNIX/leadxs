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
    # Get all active filters for the campaign
    filters = DistributionFilter.where(campaign: campaign, status: 'active')
    
    # Filter distributions
    distributions.select do |distribution|
      # Get filters that apply to this distribution
      applicable_filters = filters.select { |filter| filter.applies_to?(distribution) }
      
      # Distribution passes if all applicable filters pass
      applicable_filters.all? { |filter| filter.passes?(lead_data) }
    end
  end
  
  private
  
  def validate_distributions_if_not_apply_to_all
    if !apply_to_all && distributions.empty?
      errors.add(:distributions, "must be selected if not applying to all distributions")
    end
  end
end