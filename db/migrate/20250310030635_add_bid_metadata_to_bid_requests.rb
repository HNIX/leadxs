class AddBidMetadataToBidRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :bid_requests, :bid_metadata, :jsonb, default: {}
    
    # Add index for faster queries on metadata
    add_index :bid_requests, :bid_metadata, using: :gin
  end
end
