class AddShareDuringBiddingToCampaignFields < ActiveRecord::Migration[8.0]
  def change
    add_column :campaign_fields, :share_during_bidding, :boolean, default: false
    add_column :calculated_fields, :share_during_bidding, :boolean, default: false
    
    # Add an index for faster querying
    add_index :campaign_fields, :share_during_bidding
    add_index :calculated_fields, :share_during_bidding
    
    # Check if the pii column exists before adding index
    if column_exists?(:campaign_fields, :pii)
      add_index :campaign_fields, :pii
    end
    
    # Populate the share_during_bidding field
    reversible do |dir|
      dir.up do
        # Check if anonymous_bidding_enabled column exists
        if column_exists?(:campaign_fields, :anonymous_bidding_enabled)
          if column_exists?(:campaign_fields, :pii)
            # Both columns exist
            execute <<-SQL
              UPDATE campaign_fields 
              SET share_during_bidding = 
                CASE 
                  WHEN anonymous_bidding_enabled = TRUE THEN TRUE
                  WHEN pii = FALSE AND field_type NOT IN ('ssn', 'social_security', 'credit_card', 'password') AND 
                       (name ILIKE 'zip' OR name ILIKE 'state' OR name ILIKE 'city' OR name ILIKE 'income' OR name ILIKE 'age') THEN TRUE
                  ELSE FALSE
                END
            SQL
          else
            # Only anonymous_bidding_enabled exists
            execute <<-SQL
              UPDATE campaign_fields 
              SET share_during_bidding = 
                CASE 
                  WHEN anonymous_bidding_enabled = TRUE THEN TRUE
                  WHEN field_type NOT IN ('ssn', 'social_security', 'credit_card', 'password') AND 
                       (name ILIKE 'zip' OR name ILIKE 'state' OR name ILIKE 'city' OR name ILIKE 'income' OR name ILIKE 'age') THEN TRUE
                  ELSE FALSE
                END
            SQL
          end
        else
          # None of the columns exist, use default logic for fields that are generally safe to share
          execute <<-SQL
            UPDATE campaign_fields 
            SET share_during_bidding = 
              CASE 
                WHEN field_type NOT IN ('ssn', 'social_security', 'credit_card', 'password') AND 
                     (name ILIKE 'zip' OR name ILIKE 'state' OR name ILIKE 'city' OR name ILIKE 'income' OR name ILIKE 'age') THEN TRUE
                ELSE FALSE
              END
          SQL
        end
        
        # Default calculated fields to not be shared during bidding
        execute <<-SQL
          UPDATE calculated_fields
          SET share_during_bidding = FALSE
        SQL
      end
    end
  end
end
