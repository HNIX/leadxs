class AddCascadeToCampaignFields < ActiveRecord::Migration[8.0]
  def up
    # Remove existing foreign key
    remove_foreign_key :campaign_fields, :campaigns, if_exists: true
    
    # Add foreign key with CASCADE
    add_foreign_key :campaign_fields, :campaigns, on_delete: :cascade
  end
  
  def down
    # Remove CASCADE foreign key
    remove_foreign_key :campaign_fields, :campaigns, if_exists: true
    
    # Add back normal foreign key
    add_foreign_key :campaign_fields, :campaigns
  end
end
