class CreateDistributions < ActiveRecord::Migration[8.0]
  def change
    create_table :distributions do |t|
      t.string :name, null: false
      t.text :description
      t.references :company, null: false, foreign_key: true
      t.string :endpoint_url, null: false
      t.string :authentication_token
      t.integer :status, default: 0, null: false
      t.integer :request_method, default: 1, null: false
      t.integer :request_format, default: 1, null: false
      t.text :template

      t.timestamps
    end
    
    add_index :distributions, [:company_id, :name], unique: true
  end
end
