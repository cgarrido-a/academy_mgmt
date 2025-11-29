class AddPriceToPaymentPlans < ActiveRecord::Migration[7.1]
  def change
    add_column :payment_plans, :price, :integer
  end
end
