class CreateTransbankTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :transbank_transactions do |t|
      # Reference to what is being paid
      t.references :enrollment, null: false, foreign_key: true
      t.references :installment, null: true, foreign_key: true
      t.string :payment_type, null: false # 'enrollment_fee', 'installment'

      # Transbank specific fields
      t.string :token, null: false, index: { unique: true }
      t.string :buy_order, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false

      # Transaction status
      t.string :status, default: 'pending', null: false # pending, authorized, failed, nullified

      # Response from Transbank
      t.string :authorization_code
      t.string :payment_type_code
      t.integer :response_code
      t.string :card_number # last 4 digits
      t.datetime :transaction_date

      # Additional info
      t.text :raw_response
      t.text :error_message

      t.timestamps
    end

    add_index :transbank_transactions, :buy_order
    add_index :transbank_transactions, :status
  end
end
