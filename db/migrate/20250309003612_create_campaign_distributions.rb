class CreateCampaignDistributions < ActiveRecord::Migration[8.0]
  def change
    create_table :campaign_distributions do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :distribution, null: false, foreign_key: true
      t.boolean :active, default: true, null: false
      t.integer :priority, default: 0

      t.timestamps
    end
    
    add_index :campaign_distributions, [:campaign_id, :distribution_id], unique: true
  end
end
