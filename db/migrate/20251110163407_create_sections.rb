class CreateSections < ActiveRecord::Migration[7.1]
  def change
    create_table :sections do |t|
      t.references :course, null: false, foreign_key: true
      t.references :teacher, null: false, foreign_key: true
      t.integer :places
      t.integer :schedule
      t.date :start_date
      t.date :end_date

      t.timestamps
    end
  end
end
