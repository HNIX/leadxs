class CampaignDistribution < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :campaign
  belongs_to :distribution
  has_many :mapped_fields, dependent: :destroy
  
  accepts_nested_attributes_for :mapped_fields, reject_if: :all_blank, allow_destroy: true
  
  validates :campaign_id, uniqueness: { scope: :distribution_id }
  validates :priority, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  
  after_create :set_default_field_mapping
  after_update :broadcast_to_activity_feed, if: -> { saved_change_to_last_used_at? }
  
  def active?
    active
  end
  
  def all_required_fields_mapped?
    required_campaign_field_ids = campaign.campaign_fields.where(required: true).pluck(:id)
    mapped_campaign_field_ids = mapped_fields.where.not(campaign_field_id: nil).pluck(:campaign_field_id)
    
    (required_campaign_field_ids - mapped_campaign_field_ids).empty?
  end
  
  private
  
  def set_default_field_mapping
    existing_names = {}
    
    campaign.campaign_fields.each do |campaign_field|
      # Create a basic mapping with the same name as the campaign field
      base_name = campaign_field.name.parameterize(separator: "_")
      
      # Ensure unique distribution_field_name
      field_name = base_name
      count = 1
      while existing_names[field_name]
        field_name = "#{base_name}_#{count}"
        count += 1
      end
      
      existing_names[field_name] = true
      
      mapped_fields.create(
        campaign_field_id: campaign_field.id,
        distribution_field_name: field_name,
        value_type: :dynamic,
        required: campaign_field.required
      )
    end
  end
  
  def broadcast_to_activity_feed
    ActivityFeedBroadcastJob.perform_later(self, :distribution)
  end
end
