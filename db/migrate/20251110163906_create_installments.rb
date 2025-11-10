class CreateInstallments < ActiveRecord::Migration[7.1]
  def change
    create_table :installments do |t|
      t.references :tuition_fee, null: false, foreign_key: true
      t.date :due_date
      t.integer :amount
      t.date :payment_date
      t.string :status

      t.timestamps
    end
  end
end
