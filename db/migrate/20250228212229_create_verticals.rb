class CreateVerticals < ActiveRecord::Migration[8.0]
  def change
    create_table :verticals do |t|
      t.string :name
      t.string :primary_category
      t.string :secondary_category
      t.text :description
      t.boolean :archived, default: false
      t.boolean :base, default: false
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end

    add_index :verticals, [:account_id, :primary_category]
    add_index :verticals, [:account_id, :name], unique: true
  end
end
