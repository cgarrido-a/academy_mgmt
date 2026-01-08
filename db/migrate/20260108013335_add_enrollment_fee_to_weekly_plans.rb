class AddEnrollmentFeeToWeeklyPlans < ActiveRecord::Migration[7.1]
  def change
    add_column :weekly_plans, :enrollment_fee, :integer
  end
end
