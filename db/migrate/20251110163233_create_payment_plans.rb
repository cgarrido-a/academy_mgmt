class CreatePaymentPlans < ActiveRecord::Migration[7.1]
  def change
    create_table :payment_plans do |t|
      t.integer :plan
      t.string :description

      t.timestamps
    end
  end
end
