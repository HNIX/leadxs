class AddMetadataRequirementsToDistributions < ActiveRecord::Migration[8.0]
  def change
    add_column :distributions, :metadata_requirements, :string
    add_column :distributions, :custom_metadata_fields, :jsonb
  end
end
