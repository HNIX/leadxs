class CreateConsentRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :consent_records do |t|
      t.references :account, null: false, foreign_key: true
      t.references :lead, null: false, foreign_key: true
      t.bigint :user_id
      t.string :consent_type, null: false
      t.text :consent_text, null: false
      t.string :ip_address, null: false
      t.string :user_agent
      t.datetime :consented_at, null: false
      t.datetime :expires_at
      t.string :proof_token
      t.uuid :uuid, null: false, default: -> { "gen_random_uuid()" }
      t.jsonb :metadata, default: {}
      t.boolean :revoked, default: false
      t.datetime :revoked_at
      t.text :revocation_reason

      t.timestamps
    end
    
    add_index :consent_records, :uuid, unique: true
    add_index :consent_records, [:lead_id, :consent_type]
    add_index :consent_records, :consented_at
    add_index :consent_records, :proof_token
    add_index :consent_records, :revoked
  end
end
