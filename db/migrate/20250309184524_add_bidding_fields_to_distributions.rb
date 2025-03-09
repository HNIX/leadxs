class AddBiddingFieldsToDistributions < ActiveRecord::Migration[8.0]
  def change
    add_column :distributions, :bidding_enabled, :boolean, default: true
    add_column :distributions, :bidding_timeout_seconds, :integer, default: 5
    add_column :distributions, :bid_endpoint_url, :string
    add_column :distributions, :base_bid_amount, :decimal, precision: 10, scale: 2
  end
end