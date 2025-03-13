class CreateAnomalyDetections < ActiveRecord::Migration[8.0]
  def change
    create_table :anomaly_detections do |t|
      t.string :metric
      t.float :value
      t.float :expected_value
      t.float :deviation_percent
      t.string :severity # warning, critical
      t.string :status, default: 'open' # open, acknowledged, resolved
      t.datetime :detected_at
      t.datetime :resolved_at
      t.datetime :acknowledged_at
      t.text :notes
      t.jsonb :context_data, default: {}
      t.references :anomaly_threshold, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :campaign, foreign_key: true, null: true
      t.references :distribution, foreign_key: true, null: true
      t.references :user, foreign_key: true, null: true # user who resolved/acknowledged

      t.timestamps
    end
    
    add_index :anomaly_detections, [:account_id, :status, :detected_at]
    add_index :anomaly_detections, [:account_id, :metric, :detected_at]
    add_index :anomaly_detections, :status
  end
end
