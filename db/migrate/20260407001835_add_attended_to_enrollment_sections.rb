class AddAttendedToEnrollmentSections < ActiveRecord::Migration[7.1]
  def change
    add_column :enrollment_sections, :attended, :boolean
  end
end
