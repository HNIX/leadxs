class CreateContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :contacts do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :phone
      t.references :company, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :contacts, [:account_id, :email]
  end
end
