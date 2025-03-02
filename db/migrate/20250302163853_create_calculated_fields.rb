class CreateCalculatedFields < ActiveRecord::Migration[8.0]
  def change
    create_table :calculated_fields do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :formula
      t.text :clean_formula
      t.string :status, default: "active"
      t.jsonb :error_log, default: {}

      t.timestamps
    end
    
    add_index :calculated_fields, [:campaign_id, :name], unique: true
  end
end
