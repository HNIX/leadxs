class CreateLeads < ActiveRecord::Migration[8.0]
  def change
    create_table :leads do |t|
      t.references :account, null: false, foreign_key: true
      t.references :campaign, null: false, foreign_key: true
      t.references :source, null: true, foreign_key: true
      
      t.string :unique_id, null: false
      t.integer :status, default: 0, null: false
      
      # Metadata
      t.string :ip_address
      t.string :user_agent
      t.string :referrer
      
      # Tracking
      t.datetime :first_distributed_at
      t.integer :distribution_count, default: 0
      
      t.timestamps
      
      # Add index for uniqueness
      t.index [:account_id, :unique_id], unique: true
    end
    
    create_table :lead_data do |t|
      t.references :lead, null: false, foreign_key: true
      t.references :campaign_field, null: false, foreign_key: true
      
      t.text :value
      
      t.timestamps
      
      # Add index for uniqueness
      t.index [:lead_id, :campaign_field_id], unique: true
    end
  end
end