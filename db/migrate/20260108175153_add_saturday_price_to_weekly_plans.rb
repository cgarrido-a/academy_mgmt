class AddSaturdayPriceToWeeklyPlans < ActiveRecord::Migration[7.1]
  def change
    add_column :weekly_plans, :saturday_price, :integer
  end
end
