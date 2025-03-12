class CreateStandardFields < ActiveRecord::Migration[8.0]
  def change
    create_table :standard_fields do |t|
      t.string :name
      t.string :label
      t.integer :data_type
      t.integer :value_acceptance, default: 0
      t.boolean :required, default: false
      t.text :description
      t.boolean :is_pii, default: false
      t.boolean :ping_required, default: false
      t.boolean :post_required, default: false
      t.boolean :post_only, default: false
      t.boolean :hide, default: false
      t.string :default_value
      t.string :example_value
      t.string :validation_regex
      t.integer :min_length
      t.integer :max_length
      t.decimal :min_value, precision: 10, scale: 2
      t.decimal :max_value, precision: 10, scale: 2
      t.references :account, null: false, foreign_key: true
      t.integer :position

      t.timestamps
    end
    
    add_index :standard_fields, [:account_id, :name], unique: true
  end
end
