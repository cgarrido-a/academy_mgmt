class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.references :enrollment, null: false, foreign_key: true
      t.string :payment_type, null: false # 'enrollment_fee', 'installment'
      t.references :installment, null: true, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.date :payment_date, null: false
      t.references :payment_method, null: false, foreign_key: true
      t.string :reference_number
      t.text :notes
      t.references :processed_by, null: true, foreign_key: { to_table: :users }
      t.string :status, default: 'completed', null: false

      t.timestamps
    end

    add_index :payments, [:enrollment_id, :payment_type]
    add_index :payments, :payment_date
  end
end
