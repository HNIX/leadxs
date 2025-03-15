class AddBidNotificationsFlagsToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :debug_mode, :boolean, default: false
    add_column :campaigns, :notify_on_bid, :boolean, default: false
    add_column :campaigns, :notify_on_reject, :boolean, default: false
    add_column :campaigns, :notify_on_failure, :boolean, default: false
  end
end
