class AddMultiDistributionStrategyToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :multi_distribution_strategy, :string, default: 'sequential'
    add_column :campaigns, :max_distributions, :integer, default: 1
    
    # Add an index to help with querying campaigns by strategy
    add_index :campaigns, :multi_distribution_strategy
  end
end
