class AddPreferencesToMappedFields < ActiveRecord::Migration[8.0]
  def change
    add_column :mapped_fields, :preferences, :jsonb
  end
end
