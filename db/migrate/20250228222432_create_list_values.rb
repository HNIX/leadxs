class CreateListValues < ActiveRecord::Migration[8.0]
  def change
    create_table :list_values do |t|
      t.references :list_owner, polymorphic: true
      t.references :account, null: false, foreign_key: true
      t.string :list_value, null: false
      t.integer :value_type, default: 0  # Enum: string, number
      t.integer :position
      
      t.timestamps
    end
    
    add_index :list_values, [:account_id, :list_owner_type, :list_owner_id, :position]
  end
end