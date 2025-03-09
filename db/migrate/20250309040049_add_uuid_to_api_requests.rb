class AddUuidToApiRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :api_requests, :uuid, :uuid, null: false, default: -> { "gen_random_uuid()" }
    add_index :api_requests, :uuid, unique: true
  end
end
