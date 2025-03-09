class CreateHeaders < ActiveRecord::Migration[8.0]
  def change
    create_table :headers do |t|
      t.references :distribution, null: false, foreign_key: true
      t.string :name, null: false
      t.string :value, null: false

      t.timestamps
    end
    
    add_index :headers, [:distribution_id, :name], unique: true
  end
end
