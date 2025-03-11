class CreateLeadActivityLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :lead_activity_logs do |t|
      t.references :lead, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :causer, polymorphic: true
      
      t.integer :activity_type, null: false
      t.jsonb :details, default: {}
      t.string :ip_address
      t.string :user_agent
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :lead_activity_logs, [:lead_id, :created_at]
    add_index :lead_activity_logs, :activity_type
  end
end