class CreateVerticalFields < ActiveRecord::Migration[8.0]
  def change
    create_table :vertical_fields do |t|
      t.references :vertical, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false         # snake_case field identifier
      t.string :label                     # Human-readable label
      t.integer :data_type, null: false   # Enum: text, number, boolean, date, etc.
      t.integer :position                 # For ordering in forms/docs
      t.boolean :required, default: false # Is this field required in general?
      t.boolean :is_pii, default: false   # Contains personally identifiable information
      t.boolean :ping_required, default: false  # Required in ping phase
      t.boolean :post_required, default: false  # Required in post phase
      t.boolean :post_only, default: false      # Only sent in post, never in ping
      t.boolean :hide, default: false     # Hidden field, used internally
      
      # Validation-related fields
      t.string :default_value             # Default value if none provided
      t.string :example_value             # Example for documentation
      t.integer :value_acceptance         # Enum: any, list, range
      t.decimal :min_value                # For numeric range validation
      t.decimal :max_value                # For numeric range validation

      t.timestamps
    end
    
    add_index :vertical_fields, [:account_id, :vertical_id, :name], unique: true
    add_index :vertical_fields, [:account_id, :position]
  end
end
