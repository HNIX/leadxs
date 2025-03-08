class CreateValidationRules < ActiveRecord::Migration[8.0]
  def change
    create_table :validation_rules do |t|
      t.string :rule_type, null: false, index: true
      t.references :validatable, polymorphic: true, null: false, index: true
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.text :condition, null: false
      t.string :error_message, null: false
      t.string :severity, default: 'error'
      t.integer :position, default: 0
      t.boolean :active, default: true
      t.jsonb :parameters, default: {}
      t.jsonb :test_data, default: {}

      t.timestamps
    end
    
    add_index :validation_rules, [:validatable_type, :validatable_id, :name], unique: true, name: 'index_validation_rules_on_validatable_and_name'
  end
end
