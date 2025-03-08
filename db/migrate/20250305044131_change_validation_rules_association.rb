class ChangeValidationRulesAssociation < ActiveRecord::Migration[8.0]
  def up
    # Add campaign_id column
    add_column :validation_rules, :campaign_id, :bigint
    add_index :validation_rules, :campaign_id
    
    # Add foreign key constraint
    add_foreign_key :validation_rules, :campaigns
    
    # Move existing validation rules from campaign_fields to campaigns
    execute <<-SQL
      UPDATE validation_rules
      SET campaign_id = (
        SELECT campaign_id
        FROM campaign_fields
        WHERE campaign_fields.id = validation_rules.validatable_id
          AND validation_rules.validatable_type = 'CampaignField'
      )
      WHERE validatable_type = 'CampaignField'
    SQL
    
    # For any validation rules that couldn't be migrated (should be rare), mark them
    # We won't remove these records just yet to avoid losing data
    add_column :validation_rules, :legacy, :boolean, default: false
    execute <<-SQL
      UPDATE validation_rules
      SET legacy = true
      WHERE validatable_type = 'CampaignField' AND campaign_id IS NULL
    SQL
    
    # Vertical field validation rules should remain untouched
  end

  def down
    # This migration is not easily reversible since we're changing the association model
    # We'll keep the columns for safety
    remove_index :validation_rules, :campaign_id
    remove_foreign_key :validation_rules, :campaigns
    remove_column :validation_rules, :campaign_id
    remove_column :validation_rules, :legacy
  end
end
