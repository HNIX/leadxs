class CreateCampaignFields < ActiveRecord::Migration[8.0]
  def change
    create_table :campaign_fields do |t|
      t.string :name
      t.string :field_type
      t.boolean :required
      t.string :default_value
      t.text :description
      t.string :validation_regex
      t.integer :min_length
      t.integer :max_length
      t.float :min_value
      t.float :max_value
      t.text :options
      t.integer :position
      t.references :campaign, null: false, foreign_key: true
      t.references :vertical_field, null: false, foreign_key: true

      t.timestamps
    end
  end
end
