class CreateCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :companies do |t|
      t.string :name
      t.string :address
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :billing_cycle
      t.string :payment_terms
      t.string :currency
      t.string :tax_id
      t.text :notes
      t.string :status, default: "active"
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :companies, [:account_id, :name]
  end
end
