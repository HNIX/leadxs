class CreateAnomalyThresholds < ActiveRecord::Migration[8.0]
  def change
    create_table :anomaly_thresholds do |t|
      t.string :name
      t.string :metric
      t.string :threshold_type  # absolute, percentage, std_dev
      t.float :threshold_value
      t.string :lookback_period # hourly, daily, weekly
      t.string :severity # warning, critical
      t.jsonb :metadata, default: {}
      t.boolean :active, default: true
      t.boolean :auto_resolve, default: false
      t.text :description
      t.references :account, null: false, foreign_key: true
      t.references :campaign, foreign_key: true, null: true
      t.references :distribution, foreign_key: true, null: true

      t.timestamps
    end
    
    add_index :anomaly_thresholds, [:account_id, :metric, :active]
    add_index :anomaly_thresholds, [:account_id, :campaign_id, :metric], where: "campaign_id IS NOT NULL"
    add_index :anomaly_thresholds, [:account_id, :distribution_id, :metric], where: "distribution_id IS NOT NULL"
  end
end
