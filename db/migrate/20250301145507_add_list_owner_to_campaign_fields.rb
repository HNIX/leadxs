class AddListOwnerToCampaignFields < ActiveRecord::Migration[8.0]
  def up
    # Add account_id initially as nullable
    add_reference :campaign_fields, :account, null: true, foreign_key: true
    
    # Update existing campaign_fields to have the same account_id as their campaign
    execute <<-SQL
      UPDATE campaign_fields 
      SET account_id = campaigns.account_id 
      FROM campaigns 
      WHERE campaign_fields.campaign_id = campaigns.id
    SQL
    
    # Make account_id non-nullable
    change_column_null :campaign_fields, :account_id, false
    
    # Add an index for the polymorphic list_owner association if it doesn't exist
    unless index_exists?(:list_values, [:list_owner_type, :list_owner_id, :position], name: 'index_list_values_on_owner_and_position')
      add_index :list_values, [:list_owner_type, :list_owner_id, :position], name: 'index_list_values_on_owner_and_position'
    end
  end

  def down
    remove_reference :campaign_fields, :account, foreign_key: true
    remove_index :list_values, name: 'index_list_values_on_owner_and_position', if_exists: true
  end
end
