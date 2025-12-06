class DropTuitionFeesTable < ActiveRecord::Migration[7.1]
  def up
    # Remove foreign keys first if they exist
    if foreign_key_exists?(:tuition_fees, :enrollments)
      remove_foreign_key :tuition_fees, :enrollments
    end

    if foreign_key_exists?(:tuition_fees, :payment_methods)
      remove_foreign_key :tuition_fees, :payment_methods
    end

    # Drop the table if it exists
    drop_table :tuition_fees if table_exists?(:tuition_fees)
  end

  def down
    # Cannot easily reverse this migration
    raise ActiveRecord::IrreversibleMigration
  end
end
