class RenameAmountFieldsInEnrollmentsAndTuitionFees < ActiveRecord::Migration[7.1]
  def change
    # Rename amount to enrollment_amount in enrollments table
    rename_column :enrollments, :amount, :enrollment_amount

    # Rename total_amount to total_tuition_fee in tuition_fees table
    rename_column :tuition_fees, :total_amount, :total_tuition_fee
  end
end
