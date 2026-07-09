class AddCourseToWeeklyPlans < ActiveRecord::Migration[7.1]
  def change
    # Nullable: los planes existentes quedan sin curso hasta que se asignen
    # manualmente desde el panel admin.
    add_reference :weekly_plans, :course, null: true, foreign_key: true
  end
end
