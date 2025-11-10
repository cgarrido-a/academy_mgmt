class CreateTuitionFees < ActiveRecord::Migration[7.1]
  def change
    create_table :tuition_fees do |t|
      t.references :enrollment, null: false, foreign_key: true
      t.references :payment_method, null: false, foreign_key: true
      t.string :billing_period
      t.integer :total_amount
      t.integer :instalments_number

      t.timestamps
    end
  end
end
