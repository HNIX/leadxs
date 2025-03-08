class RemoveCampaignAndVerticalFromValidationRules < ActiveRecord::Migration[8.0]
  def up
    # Remove foreign key if it exists
    if foreign_key_exists?(:validation_rules, :campaigns)
      remove_foreign_key :validation_rules, :campaigns
    end

    if foreign_key_exists?(:validation_rules, :verticals)
      remove_foreign_key :validation_rules, :verticals
    end
    
    # Remove index if it exists
    if index_exists?(:validation_rules, :campaign_id)
      remove_index :validation_rules, :campaign_id
    end

    # Remove index if it exists
    if index_exists?(:validation_rules, :vertical_id)
      remove_index :validation_rules, :vertical_id
    end
    
    # Remove the campaign_id column
    remove_column :validation_rules, :campaign_id
    remove_column :validation_rules, :vertical_id
  end

  def down
    # Add the campaign_id column back
    add_reference :validation_rules, :campaign, foreign_key: true
    add_reference :validation_rules, :vertical, foreign_key: true
  end
end
