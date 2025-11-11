class ChangePlanColumnToStringInPaymentPlans < ActiveRecord::Migration[7.1]
  def up
    change_column :payment_plans, :plan, :string
    change_column :payment_plans, :description, :text
  end

  def down
    change_column :payment_plans, :plan, :integer
    change_column :payment_plans, :description, :string
  end
end
