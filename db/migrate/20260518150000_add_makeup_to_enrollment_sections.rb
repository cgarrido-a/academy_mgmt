class AddMakeupToEnrollmentSections < ActiveRecord::Migration[7.1]
  def change
    add_column :enrollment_sections, :kind, :string, default: 'regular', null: false
    add_column :enrollment_sections, :makes_up_for_id, :bigint
    add_column :enrollment_sections, :makeup_reason, :text

    add_index :enrollment_sections, :kind
    add_index :enrollment_sections, :makes_up_for_id, unique: true
    add_foreign_key :enrollment_sections, :enrollment_sections, column: :makes_up_for_id
  end
end
