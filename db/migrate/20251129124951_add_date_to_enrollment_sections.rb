class AddDateToEnrollmentSections < ActiveRecord::Migration[7.1]
  def change
    add_column :enrollment_sections, :date, :date

    # Remove old unique index (enrollment_id, section_id)
    remove_index :enrollment_sections, name: "index_enrollment_sections_on_enrollment_id_and_section_id"

    # Add new unique index including date
    # This allows a student to enroll in the same section on different dates
    add_index :enrollment_sections, [:enrollment_id, :section_id, :date],
              unique: true,
              name: "index_enrollment_sections_on_enrollment_section_and_date"
  end
end
