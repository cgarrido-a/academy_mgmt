class CreateSalaryPayments < ActiveRecord::Migration[7.1]
  def change
    create_table :salary_payments do |t|
      t.references :teacher, null: false, foreign_key: true
      t.references :payment_method, null: false, foreign_key: true
      t.integer :amount
      t.string :status
      t.date :payment_date

      t.timestamps
    end
  end
end
