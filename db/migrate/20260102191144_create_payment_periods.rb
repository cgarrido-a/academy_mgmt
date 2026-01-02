class CreatePaymentPeriods < ActiveRecord::Migration[7.1]
  def change
    create_table :payment_periods do |t|
      t.integer :months
      t.decimal :discount_percentage
      t.text :description

      t.timestamps
    end
  end
end
