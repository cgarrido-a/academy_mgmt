class RenamePaymentPlansToWeeklyPlans < ActiveRecord::Migration[7.1]
  def change
    # Renombrar la tabla
    rename_table :payment_plans, :weekly_plans

    # Renombrar la columna de foreign key en enrollments
    rename_column :enrollments, :payment_plan_id, :weekly_plan_id
  end
end
