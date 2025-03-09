class CreateBids < ActiveRecord::Migration[8.0]
  def change
    create_table :bids do |t|
      t.references :account, null: false, foreign_key: true
      t.references :bid_request, null: false, foreign_key: true
      t.references :distribution, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false, default: 0
      t.integer :status, null: false, default: 0
      
      t.timestamps
      
      t.index [:bid_request_id, :distribution_id], unique: true
      t.index [:account_id, :status]
      t.index :amount
    end
  end
end