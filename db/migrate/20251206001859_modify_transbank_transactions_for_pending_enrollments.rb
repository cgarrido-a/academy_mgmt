class ModifyTransbankTransactionsForPendingEnrollments < ActiveRecord::Migration[7.1]
  def change
    # Make enrollment_id nullable to allow creating transactions before enrollment exists
    change_column_null :transbank_transactions, :enrollment_id, true

    # Add jsonb column to store enrollment data for pending transactions
    add_column :transbank_transactions, :enrollment_data, :jsonb
  end
end
