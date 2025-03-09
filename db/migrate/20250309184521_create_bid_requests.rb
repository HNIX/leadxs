class CreateBidRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :bid_requests do |t|
      t.references :account, null: false, foreign_key: true
      t.references :campaign, null: false, foreign_key: true
      t.references :lead, foreign_key: true
      t.string :unique_id, null: false
      t.integer :status, null: false, default: 0
      t.datetime :expires_at, null: false
      t.jsonb :anonymized_data, null: false, default: {}
      
      t.timestamps
      
      t.index :unique_id, unique: true
      t.index [:account_id, :unique_id], unique: true
      t.index :status
      t.index :expires_at
    end
  end
end