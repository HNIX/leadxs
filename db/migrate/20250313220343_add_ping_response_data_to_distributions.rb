class AddPingResponseDataToDistributions < ActiveRecord::Migration[8.0]
  def change
    add_column :distributions, :ping_response_data, :text
  end
end
