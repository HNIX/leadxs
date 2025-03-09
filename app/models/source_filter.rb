class SourceFilter < Filter
  acts_as_tenant :account
  
  # Source-specific associations
  has_many :source_filter_assignments, dependent: :destroy
  has_many :sources, through: :source_filter_assignments

  
  # Source-specific validations
  validates :apply_to_all, inclusion: { in: [true, false] }
  validate :validate_sources_if_not_apply_to_all
  
  # Determine if this filter applies to a specific source
  def applies_to?(source)
    return true if apply_to_all
    sources.include?(source)
  end
  
  # Class method to filter sources based on lead data
  def self.filter_sources(sources, lead_data, campaign)
    # Get all active filters for the campaign
    filters = SourceFilter.where(campaign: campaign, status: 'active')
    
    # Filter sources
    sources.select do |source|
      # Get filters that apply to this source
      applicable_filters = filters.select { |filter| filter.applies_to?(source) }
      
      # Source passes if all applicable filters pass
      applicable_filters.all? { |filter| filter.passes?(lead_data) }
    end
  end
  
  private
  
  def validate_sources_if_not_apply_to_all
    if !apply_to_all && sources.empty?
      errors.add(:sources, "must be selected if not applying to all sources")
    end
  end
end