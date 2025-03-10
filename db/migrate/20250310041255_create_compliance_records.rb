class CreateComplianceRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :compliance_records do |t|
      t.references :account, null: false, foreign_key: true
      t.string :record_type, null: false
      t.bigint :record_id, null: false
      t.string :action, null: false
      t.string :event_type, null: false
      t.jsonb :data, default: {}
      t.bigint :user_id
      t.string :ip_address
      t.string :user_agent
      t.datetime :occurred_at, null: false

      t.timestamps
    end
    
    add_index :compliance_records, [:record_type, :record_id]
    add_index :compliance_records, [:account_id, :event_type]
    add_index :compliance_records, :occurred_at
  end
end
