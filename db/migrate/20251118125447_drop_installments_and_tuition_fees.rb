class DropInstallmentsAndTuitionFees < ActiveRecord::Migration[7.1]
  def up
    # Remove foreign keys first
    if foreign_key_exists?(:payments, :installments)
      remove_foreign_key :payments, :installments
    end

    if foreign_key_exists?(:transbank_transactions, :installments)
      remove_foreign_key :transbank_transactions, :installments
    end

    # Drop tables
    drop_table :installments if table_exists?(:installments)
  end

  def down
    # Cannot reverse this migration easily

  end
end
