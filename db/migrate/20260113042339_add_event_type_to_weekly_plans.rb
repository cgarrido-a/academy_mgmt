class AddEventTypeToWeeklyPlans < ActiveRecord::Migration[7.1]
  def change
    add_column :weekly_plans, :event_type, :integer
  end
end
