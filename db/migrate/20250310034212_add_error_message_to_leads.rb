class AddErrorMessageToLeads < ActiveRecord::Migration[8.0]
  def change
    add_column :leads, :error_message, :text
  end
end
