class AddTotalTuitionFeeToEnrollment < ActiveRecord::Migration[7.1]
  def change
    add_column :enrollments, :total_tuition_fee, :integer
  end
end
