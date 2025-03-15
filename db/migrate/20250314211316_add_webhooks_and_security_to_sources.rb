class AddWebhooksAndSecurityToSources < ActiveRecord::Migration[8.0]
  def change
    add_column :sources, :webhook_url, :string
    add_column :sources, :webhook_secret, :string
    add_column :sources, :success_postback_url, :string
    add_column :sources, :failure_postback_url, :string
    add_column :sources, :ip_whitelist, :string
    add_column :sources, :allowed_domains, :string
  end
end
