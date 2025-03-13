class AddFallbackToBids < ActiveRecord::Migration[8.0]
  def change
    add_column :bids, :is_fallback, :boolean, default: false, null: false
    add_column :distributions, :bid_on_error, :boolean, default: false, null: false
  end
end
