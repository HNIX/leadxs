class AddCompletedAtToBidRequests < ActiveRecord::Migration[8.0]
  def up
    add_column :bid_requests, :completed_at, :datetime
    
    # Set completed_at for existing completed requests
    execute <<-SQL
      UPDATE bid_requests
      SET completed_at = updated_at
      WHERE status = 20
    SQL
  end
  
  def down
    remove_column :bid_requests, :completed_at
  end
end
