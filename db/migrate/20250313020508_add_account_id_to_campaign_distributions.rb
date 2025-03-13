class AddAccountIdToCampaignDistributions < ActiveRecord::Migration[8.0]
  def up
    # Add the column, but allow nulls initially
    add_reference :campaign_distributions, :account, null: true, foreign_key: true

    # Set the account_id based on the campaign's account_id for each record
    execute <<-SQL
      UPDATE campaign_distributions 
      SET account_id = campaigns.account_id 
      FROM campaigns 
      WHERE campaign_distributions.campaign_id = campaigns.id
    SQL

    # Now make the column non-nullable
    change_column_null :campaign_distributions, :account_id, false
  end

  def down
    remove_reference :campaign_distributions, :account
  end
end
