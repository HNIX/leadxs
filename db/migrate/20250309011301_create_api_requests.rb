class CreateApiRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :api_requests do |t|
      t.references :requestable, polymorphic: true, null: false
      # We'll add the lead reference later when Lead model exists
      t.bigint :lead_id
      t.string :endpoint_url, null: false
      t.integer :request_method, null: false
      t.text :request_payload
      t.integer :response_code
      t.text :response_payload
      t.integer :duration_ms
      t.text :error
      t.datetime :sent_at

      t.timestamps
    end
    
    add_index :api_requests, [:requestable_type, :requestable_id, :created_at]
  end
end
