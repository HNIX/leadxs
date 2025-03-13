class AddAccountIdToFormBuilders < ActiveRecord::Migration[8.0]
  def change
    add_reference :form_builders, :account, null: false, foreign_key: true
    add_reference :form_builder_analytics, :account, null: false, foreign_key: true
    add_reference :form_submissions, :account, null: false, foreign_key: true
    add_reference :form_builder_elements, :account, null: false, foreign_key: true
  end
end
