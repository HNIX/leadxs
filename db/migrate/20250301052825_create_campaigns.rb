class CreateCampaigns < ActiveRecord::Migration[8.0]
  def change
    create_table :campaigns do |t|
      t.string :name
      t.string :status
      t.string :campaign_type
      t.text :description
      t.string :distribution_method
      t.boolean :distribution_schedule_enabled
      t.string :distribution_schedule_days
      t.time :distribution_schedule_start_time
      t.time :distribution_schedule_end_time
      t.references :vertical, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end
  end
end
