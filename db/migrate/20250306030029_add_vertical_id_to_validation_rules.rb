class AddVerticalIdToValidationRules < ActiveRecord::Migration[8.0]
  def up
    # Add vertical_id column
    add_column :validation_rules, :vertical_id, :bigint
    add_index :validation_rules, :vertical_id
    
    # Add foreign key constraint
    add_foreign_key :validation_rules, :verticals

    # Move existing validation rules from vertical_fields to verticals
    execute <<-SQL
      UPDATE validation_rules
      SET vertical_id = (
        SELECT vertical_id
        FROM vertical_fields
        WHERE vertical_fields.id = validation_rules.validatable_id
          AND validation_rules.validatable_type = 'VerticalField'
      )
      WHERE validatable_type = 'VerticalField'
    SQL
    
    # For any validation rules that couldn't be migrated, mark them as legacy
    execute <<-SQL
      UPDATE validation_rules
      SET legacy = true
      WHERE validatable_type = 'VerticalField' AND vertical_id IS NULL AND legacy IS NULL
    SQL
  end

  def down
    # Remove the column
    remove_index :validation_rules, :vertical_id
    remove_foreign_key :validation_rules, :verticals
    remove_column :validation_rules, :vertical_id
  end
end
