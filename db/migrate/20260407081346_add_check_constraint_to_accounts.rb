class AddCheckConstraintToAccounts < ActiveRecord::Migration[8.1]
  def up
    safety_assured {
      execute <<-SQL
        ALTER TABLE accounts ADD CONSTRAINT accounts_balance_non_negative
        CHECK (balance >= 0);
      SQL
    }
  end

  def down
    safety_assured {
      execute <<-SQL
        ALTER TABLE accounts DROP CONSTRAINT IF EXISTS accounts_balance_non_negative;
      SQL
    }
  end
end
