class CreateClassSuspensions < ActiveRecord::Migration[7.1]
  def change
    create_table :class_suspensions do |t|
      t.references :section, null: false, foreign_key: true
      t.date :original_date, null: false
      t.text :reason
      t.references :created_by, null: true, foreign_key: { to_table: :users }
      t.integer :affected_count, null: false, default: 0

      t.timestamps
    end

    add_reference :enrollment_sections, :class_suspension, null: true, foreign_key: true
  end
end
