class AddRequestHeadersToApiRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :api_requests, :request_headers, :jsonb
  end
end
