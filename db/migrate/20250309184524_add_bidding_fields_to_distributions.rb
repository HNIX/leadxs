class AddBiddingFieldsToDistributions < ActiveRecord::Migration[8.0]
  def change
    add_column :distributions, :bidding_strategy, :integer, default: 0
    add_column :distributions, :base_bid_amount, :decimal, precision: 10, scale: 2
    add_column :distributions, :min_bid_amount, :decimal, precision: 10, scale: 2
    add_column :distributions, :max_bid_amount, :decimal, precision: 10, scale: 2
    add_column :distributions, :bid_endpoint_url, :string
  end
end