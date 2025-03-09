class AddBiddingFieldsToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :bid_timeout_seconds, :integer, default: 5
    add_column :campaigns, :minimum_bid_amount, :decimal, precision: 10, scale: 2
  end
end