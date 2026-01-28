class DropSalaryPayments < ActiveRecord::Migration[7.1]
  def up
    drop_table :salary_payments
  end

  def down
    create_table :salary_payments do |t|
      t.integer :teacher_id, null: false
      t.integer :payment_method_id, null: false
      t.integer :amount
      t.string :status
      t.date :payment_date

      t.timestamps
    end

    add_index :salary_payments, :teacher_id
    add_index :salary_payments, :payment_method_id
    add_foreign_key :salary_payments, :teachers
    add_foreign_key :salary_payments, :payment_methods
  end
end
