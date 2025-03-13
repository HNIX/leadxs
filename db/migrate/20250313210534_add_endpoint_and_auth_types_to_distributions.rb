class AddEndpointAndAuthTypesToDistributions < ActiveRecord::Migration[8.0]
  def change
    # Add endpoint type enum
    add_column :distributions, :endpoint_type, :integer, default: 0, null: false
    
    # Add authentication method enum
    add_column :distributions, :authentication_method, :integer, default: 0, null: false
    
    # Add authentication fields
    add_column :distributions, :username, :string
    add_column :distributions, :password, :string
    add_column :distributions, :api_key_name, :string, default: "X-API-Key"
    add_column :distributions, :api_key_location, :string, default: "header"
    
    # OAuth fields
    add_column :distributions, :client_id, :string
    add_column :distributions, :client_secret, :string
    add_column :distributions, :token_url, :string
    add_column :distributions, :refresh_token, :string
    add_column :distributions, :access_token, :string
    add_column :distributions, :token_expires_at, :datetime
    
    # Post endpoint options
    add_column :distributions, :post_endpoint_url, :string
    
    # Add index for faster querying by endpoint type and auth method
    add_index :distributions, [:endpoint_type, :authentication_method]
  end
end
