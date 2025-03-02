class ChangeVerticalFieldIdToOptionalForCampaignFields < ActiveRecord::Migration[8.0]
  def change
    change_column_null :campaign_fields, :vertical_field_id, true
  end
end
