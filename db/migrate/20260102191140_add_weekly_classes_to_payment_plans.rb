class AddWeeklyClassesToPaymentPlans < ActiveRecord::Migration[7.1]
  def change
    add_column :payment_plans, :weekly_classes, :integer
  end
end
