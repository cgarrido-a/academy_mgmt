class AddClassPriceToPaymentPlans < ActiveRecord::Migration[7.1]
  def change
    add_column :payment_plans, :class_price, :integer
  end
end
