class CreatePaymentMethods < ActiveRecord::Migration[7.1]
  def change
    create_table :payment_methods do |t|
      t.string :payment_method

      t.timestamps
    end
  end
end
