class AddIndexToCampaignFields < ActiveRecord::Migration[8.0]
  def change
    add_index :campaign_fields, [:campaign_id, :position], name: 'index_campaign_fields_on_campaign_id_and_position'
    add_index :campaign_fields, [:account_id, :campaign_id, :name], name: 'index_campaign_fields_on_account_campaign_and_name', unique: true
  end
end
