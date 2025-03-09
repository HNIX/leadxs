class CreateFilters < ActiveRecord::Migration[8.0]
  def change
    create_table :filters do |t|
      t.references :account, null: false, foreign_key: true
      t.references :campaign, null: false, foreign_key: true
      t.references :campaign_field, null: false, foreign_key: true
      t.string :type, null: false
      t.string :operator, null: false
      t.string :value
      t.decimal :min_value, precision: 10, scale: 2
      t.decimal :max_value, precision: 10, scale: 2
      t.string :status, null: false, default: 'active'
      t.boolean :apply_to_all, null: false, default: true

      t.timestamps
    end
    
    create_table :source_filter_assignments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :source_filter, null: false, foreign_key: { to_table: :filters }
      t.references :source, null: false, foreign_key: true

      t.timestamps
      
      t.index [:account_id, :source_filter_id, :source_id], unique: true, name: 'idx_source_filter_assignments_uniqueness'
    end
    
    create_table :distribution_filter_assignments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :distribution_filter, null: false, foreign_key: { to_table: :filters }
      t.references :distribution, null: false, foreign_key: true

      t.timestamps
      
      t.index [:account_id, :distribution_filter_id, :distribution_id], unique: true, name: 'idx_distribution_filter_assignments_uniqueness'
    end
    
    add_index :filters, [:type, :account_id, :campaign_id]
  end
end