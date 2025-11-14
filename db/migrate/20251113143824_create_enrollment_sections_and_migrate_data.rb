class CreateEnrollmentSectionsAndMigrateData < ActiveRecord::Migration[7.1]
  def up
    # Create enrollment_sections table
    create_table :enrollment_sections do |t|
      t.references :enrollment, null: false, foreign_key: true
      t.references :section, null: false, foreign_key: true

      t.timestamps
    end

    # Add unique index to prevent duplicate enrollments in the same section
    add_index :enrollment_sections, [:enrollment_id, :section_id], unique: true

    # Migrate existing data from enrollments.section_id to enrollment_sections
    # Only migrate if there are existing enrollments with section_id
    execute <<-SQL
      INSERT INTO enrollment_sections (enrollment_id, section_id, created_at, updated_at)
      SELECT id, section_id, created_at, updated_at
      FROM enrollments
      WHERE section_id IS NOT NULL
    SQL

    # Remove section_id from enrollments
    remove_foreign_key :enrollments, :sections
    remove_column :enrollments, :section_id
  end

  def down
    # Add section_id back to enrollments
    add_reference :enrollments, :section, null: true, foreign_key: true

    # Migrate data back from enrollment_sections to enrollments
    # Take the first section for each enrollment (in case there are multiple)
    execute <<-SQL
      UPDATE enrollments
      SET section_id = (
        SELECT section_id
        FROM enrollment_sections
        WHERE enrollment_sections.enrollment_id = enrollments.id
        LIMIT 1
      )
    SQL

    # Make section_id not nullable again
    change_column_null :enrollments, :section_id, false

    # Drop enrollment_sections table
    drop_table :enrollment_sections
  end
end
