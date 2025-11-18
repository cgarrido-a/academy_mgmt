class RemoveInstallmentsForeignKeys < ActiveRecord::Migration[7.1]
  def change
    # Remove foreign key from payments if it exists
    if foreign_key_exists?(:payments, column: :installment_id)
      remove_foreign_key :payments, column: :installment_id
    end

    # Remove foreign key from transbank_transactions if it exists
    if foreign_key_exists?(:transbank_transactions, column: :installment_id)
      remove_foreign_key :transbank_transactions, column: :installment_id
    end

    # Remove the columns
    if column_exists?(:payments, :installment_id)
      remove_column :payments, :installment_id
    end

    if column_exists?(:transbank_transactions, :installment_id)
      remove_column :transbank_transactions, :installment_id
    end
  end
end
