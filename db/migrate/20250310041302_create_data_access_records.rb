class CreateDataAccessRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :data_access_records do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :record_type, null: false
      t.bigint :record_id, null: false
      t.string :action, null: false
      t.string :purpose
      t.string :ip_address
      t.string :user_agent
      t.datetime :accessed_at, null: false
      t.jsonb :fields_accessed, default: []
      t.string :access_context

      t.timestamps
    end
    
    add_index :data_access_records, [:record_type, :record_id]
    add_index :data_access_records, [:user_id, :accessed_at]
    add_index :data_access_records, [:account_id, :accessed_at]
  end
end
