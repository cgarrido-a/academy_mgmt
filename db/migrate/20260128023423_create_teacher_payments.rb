class CreateTeacherPayments < ActiveRecord::Migration[7.1]
  def change
    create_table :teacher_payments do |t|
      t.references :teacher, null: false, foreign_key: true
      t.references :payment_method, null: false, foreign_key: true
      t.integer :amount
      t.string :status, default: 'pending'
      t.date :payment_date
      t.date :period_start
      t.date :period_end
      t.text :notes

      t.timestamps
    end
  end
end
