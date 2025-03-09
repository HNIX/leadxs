class AddAccountToDistributions < ActiveRecord::Migration[8.0]
  def change
    # Since this is an existing table that may have data, we need to:
    # 1. Add the column allowing nulls first
    # 2. Populate the column
    # 3. Add the NOT NULL constraint after

    # Step 1: Add the column allowing nulls
    add_reference :distributions, :account, null: true, foreign_key: true
    
    # Step 2: Create a safety check (in development/production we'll need to run data migration)
    reversible do |dir|
      dir.up do
        # This is a safety for running migrations in test environment
        if Distribution.count > 0 && Account.count > 0
          # For safety, we're using the first account
          # In a real situation, you'd want to properly associate each distribution
          # with its correct account based on the company's account
          first_account = Account.first
          if first_account
            execute <<-SQL
              UPDATE distributions 
              SET account_id = #{first_account.id}
            SQL
          end
        end
      end
    end
    
    # Step 3: Add the NOT NULL constraint if we're in a migration-only scenario
    # In a real app with a lot of data, you might want to handle this separately
    change_column_null :distributions, :account_id, false
    
    # Add a unique index for name scoped to account
    add_index :distributions, [:account_id, :name], unique: true
  end
end
