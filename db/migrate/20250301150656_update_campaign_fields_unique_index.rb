class UpdateCampaignFieldsUniqueIndex < ActiveRecord::Migration[8.0]
  def up
    # Remove the current unique index
    remove_index :campaign_fields, name: 'index_campaign_fields_on_account_campaign_and_name', if_exists: true
    
    # Add a non-unique index for performance
    add_index :campaign_fields, [:account_id, :campaign_id, :name], name: 'index_campaign_fields_on_account_campaign_and_name', unique: false, if_not_exists: true
  end
  
  def down
    # Remove the non-unique index
    remove_index :campaign_fields, name: 'index_campaign_fields_on_account_campaign_and_name', if_exists: true
    
    # Re-add the unique index
    add_index :campaign_fields, [:account_id, :campaign_id, :name], name: 'index_campaign_fields_on_account_campaign_and_name', unique: true, if_not_exists: true
  end
end
