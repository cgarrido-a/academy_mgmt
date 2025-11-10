class CreateEnrollments < ActiveRecord::Migration[7.1]
  def change
    create_table :enrollments do |t|
      t.references :student, null: false, foreign_key: true
      t.references :payment_plan, null: false, foreign_key: true
      t.references :section, null: false, foreign_key: true
      t.references :payment_method, null: false, foreign_key: true
      t.integer :amount
      t.date :payment_date

      t.timestamps
    end
  end
end
