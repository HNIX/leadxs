class CreateSources < ActiveRecord::Migration[8.0]
  def change
    create_table :sources do |t|
      t.string :name, null: false
      t.string :token, null: false
      t.string :status, null: false, default: 'active'
      t.string :integration_type, null: false
      t.string :payout_method
      t.string :payout_structure
      t.decimal :minimum_acceptable_bid, precision: 10, scale: 2
      t.decimal :margin, precision: 10, scale: 2
      t.decimal :payout, precision: 10, scale: 2
      t.decimal :daily_budget, precision: 10, scale: 2
      t.decimal :monthly_budget, precision: 10, scale: 2
      t.text :notes
      t.references :campaign, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end

    add_index :sources, [:name, :account_id], unique: true
    add_index :sources, :token, unique: true
  end
end
