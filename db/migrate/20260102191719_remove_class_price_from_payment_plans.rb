class RemoveClassPriceFromPaymentPlans < ActiveRecord::Migration[7.1]
  def change
    remove_column :payment_plans, :class_price, :integer
  end
end
