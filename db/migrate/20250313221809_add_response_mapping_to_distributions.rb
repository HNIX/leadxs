class AddResponseMappingToDistributions < ActiveRecord::Migration[8.0]
  def change
    add_column :distributions, :response_mapping, :jsonb, default: {}, null: false
    add_column :distributions, :request_mapping, :jsonb, default: {}, null: false
    add_column :distributions, :ping_id_field, :string
    add_column :distributions, :ping_id_target_field, :string
  end
end
