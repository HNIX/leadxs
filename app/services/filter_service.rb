class FilterService
  # Takes lead data and returns eligible sources and distributions based on filters
  def self.evaluate_filters(lead_data, campaign)
    # Get active sources for the campaign
    sources = Source.where(campaign: campaign, status: 'active')
    
    # Get active distributions for the campaign
    distributions = campaign.distributions.active
    
    # Apply source filters
    eligible_sources = SourceFilter.filter_sources(sources, lead_data, campaign)
    
    # Apply distribution filters
    eligible_distributions = DistributionFilter.filter_distributions(distributions, lead_data, campaign)
    
    {
      sources: eligible_sources,
      distributions: eligible_distributions
    }
  end
  
  # Returns a hash of filter data for UI display
  def self.filter_data_for_campaign(campaign)
    {
      source_filters: campaign.source_filters.includes(:campaign_field, :sources),
      distribution_filters: campaign.distribution_filters.includes(:campaign_field, :distributions),
      fields: campaign.campaign_fields.ordered.map { |field| { id: field.id, name: field.name, label: field.label || field.name } },
      operators: filter_operators
    }
  end
  
  # Returns filter operators in a format suitable for select lists
  def self.filter_operators
    Filter::OPERATORS.map do |key, value|
      {
        id: value,
        name: key.to_s.titleize,
        value: value
      }
    end
  end
  
  # Determines if a specific entity (source or distribution) passes all relevant filters
  def self.entity_passes_filters?(entity, lead_data, campaign)
    if entity.is_a?(Source)
      # Apply source filters
      filters = SourceFilter.where(campaign: campaign, status: 'active')
      applicable_filters = filters.select { |filter| filter.applies_to?(entity) }
      applicable_filters.all? { |filter| filter.passes?(lead_data) }
    elsif entity.is_a?(Distribution)
      # Apply distribution filters
      filters = DistributionFilter.where(campaign: campaign, status: 'active')
      applicable_filters = filters.select { |filter| filter.applies_to?(entity) }
      applicable_filters.all? { |filter| filter.passes?(lead_data) }
    else
      false
    end
  end
end