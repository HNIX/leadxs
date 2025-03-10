class AddLastUsedAtToCampaignDistributions < ActiveRecord::Migration[8.0]
  def change
    add_column :campaign_distributions, :last_used_at, :datetime
  end
end
