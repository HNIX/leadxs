class CreateBidAnalyticSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :bid_analytic_snapshots do |t|
      t.references :account, null: false, foreign_key: true
      t.datetime :period_start, null: false
      t.datetime :period_end, null: false
      t.string :period_type, null: false
      t.jsonb :metrics, null: false, default: {}
      t.integer :total_bids, null: false, default: 0
      t.integer :accepted_bids, null: false, default: 0
      t.integer :rejected_bids, null: false, default: 0
      t.integer :expired_bids, null: false, default: 0
      t.decimal :avg_bid_amount, precision: 10, scale: 2, null: false, default: 0
      t.decimal :max_bid_amount, precision: 10, scale: 2, null: false, default: 0
      t.decimal :min_bid_amount, precision: 10, scale: 2, null: false, default: 0
      t.integer :conversion_count, null: false, default: 0
      t.decimal :total_revenue, precision: 10, scale: 2, null: false, default: 0
      t.references :campaign, null: true, foreign_key: true
      t.references :distribution, null: true, foreign_key: true

      t.timestamps
    end

    add_index :bid_analytic_snapshots, [:account_id, :period_type, :period_start, :period_end]
    add_index :bid_analytic_snapshots, [:account_id, :campaign_id], where: "campaign_id IS NOT NULL"
    add_index :bid_analytic_snapshots, [:account_id, :distribution_id], where: "distribution_id IS NOT NULL"
  end
end
