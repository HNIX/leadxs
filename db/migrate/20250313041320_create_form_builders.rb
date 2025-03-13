class CreateFormBuilders < ActiveRecord::Migration[8.0]
  def change
    create_table :form_builders do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :status, default: "draft", null: false
      t.jsonb :form_config, null: false, default: {}
      t.jsonb :theme_config, null: false, default: {}
      t.jsonb :tracking_config, null: false, default: {}
      t.string :embed_token, null: false
      t.timestamps
      
      t.index :embed_token, unique: true
    end
    
    create_table :form_builder_elements do |t|
      t.references :form_builder, null: false, foreign_key: { on_delete: :cascade }
      t.references :campaign_field, null: true, foreign_key: true
      t.string :element_type, null: false
      t.integer :position, null: false
      t.jsonb :properties, null: false, default: {}
      t.string :parent_element_id
      t.integer :display_condition_element_id
      t.string :display_condition_operator
      t.string :display_condition_value
      t.timestamps
      
      t.index :parent_element_id
    end
    
    create_table :form_submissions do |t|
      t.references :form_builder, null: false, foreign_key: true
      t.references :lead, null: true, foreign_key: true
      t.string :status, null: false, default: "submitted"
      t.jsonb :form_data, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.string :ip_address
      t.string :user_agent
      t.text :consent_text
      t.timestamps
      
      t.index :status
    end
    
    create_table :form_builder_analytics do |t|
      t.references :form_builder, null: false, foreign_key: { on_delete: :cascade }
      t.date :date, null: false
      t.integer :views, default: 0
      t.integer :starts, default: 0
      t.integer :submissions, default: 0
      t.integer :completions, default: 0
      t.integer :total_time_on_form_seconds, default: 0
      t.jsonb :field_dropoffs, default: {}
      t.jsonb :device_breakdown, default: {}
      t.timestamps
      
      t.index [:form_builder_id, :date], unique: true
    end
    
    # Add reference to the existing sources table to allow a source to have a form builder
    add_reference :sources, :form_builder, foreign_key: true, null: true
  end
end
