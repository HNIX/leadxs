class MappedField < ApplicationRecord
  belongs_to :campaign_distribution
  
  enum :value_type, {
    dynamic: 0,   # Uses campaign field value
    static: 1     # Uses static value specified
  }, default: :dynamic
  
  validates :distribution_field_name, presence: true, uniqueness: { scope: :campaign_distribution_id }
  validates :static_value, presence: true, if: -> { static? }
  
  def campaign_field
    return nil unless campaign_field_id.present?
    CampaignField.find_by(id: campaign_field_id)
  end
  
  def value_for_lead(lead)
    if dynamic?
      # Find the lead data for this campaign field
      lead_data = lead.lead_data.find_by(campaign_field_id: campaign_field_id)
      lead_data&.value
    else
      static_value
    end
  end
end
