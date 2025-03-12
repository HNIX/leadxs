class AddMissingColumnsToVerticalFields < ActiveRecord::Migration[8.0]
  def change
    add_column :vertical_fields, :validation_regex, :string
    add_column :vertical_fields, :min_length, :integer
    add_column :vertical_fields, :max_length, :integer
    add_column :vertical_fields, :description, :text
  end
end
