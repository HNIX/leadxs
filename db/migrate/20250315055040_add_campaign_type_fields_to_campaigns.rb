class AddCampaignTypeFieldsToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :start_date, :date
    add_column :campaigns, :end_date, :date
    add_column :campaigns, :expected_volume, :integer
    add_column :campaigns, :track_conversions, :boolean, default: false
    add_column :campaigns, :call_recording_enabled, :boolean, default: false
  end
end
