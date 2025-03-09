class EnsureMetricsDefaultForBidAnalytics < ActiveRecord::Migration[8.0]
  def up
    # Set default empty JSON for all NULL metrics values
    execute <<-SQL
      UPDATE bid_analytic_snapshots
      SET metrics = '{}'::jsonb
      WHERE metrics IS NULL
    SQL
    
    # Then add the not-null constraint with default value
    change_column_null :bid_analytic_snapshots, :metrics, false
    change_column_default :bid_analytic_snapshots, :metrics, '{}'
  end
  
  def down
    change_column_null :bid_analytic_snapshots, :metrics, true
    change_column_default :bid_analytic_snapshots, :metrics, nil
  end
end
