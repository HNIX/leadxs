class CreateMappedFields < ActiveRecord::Migration[8.0]
  def change
    create_table :mapped_fields do |t|
      t.references :campaign_distribution, null: false, foreign_key: true
      t.integer :campaign_field_id
      t.string :distribution_field_name, null: false
      t.string :static_value
      t.integer :value_type, default: 0, null: false
      t.boolean :required, default: false, null: false

      t.timestamps
    end
    
    add_index :mapped_fields, [:campaign_distribution_id, :distribution_field_name], unique: true, name: 'index_mapped_fields_on_campaign_dist_and_field_name'
  end
end
