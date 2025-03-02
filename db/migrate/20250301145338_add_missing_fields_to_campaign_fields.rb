class AddMissingFieldsToCampaignFields < ActiveRecord::Migration[8.0]
  def change
    add_column :campaign_fields, :label, :string
    add_column :campaign_fields, :data_type, :integer
    add_column :campaign_fields, :is_pii, :boolean, default: false
    add_column :campaign_fields, :ping_required, :boolean, default: false
    add_column :campaign_fields, :post_required, :boolean, default: false
    add_column :campaign_fields, :post_only, :boolean, default: false
    add_column :campaign_fields, :hide, :boolean, default: false
    add_column :campaign_fields, :example_value, :string
    add_column :campaign_fields, :value_acceptance, :integer, default: 0
  end
end
