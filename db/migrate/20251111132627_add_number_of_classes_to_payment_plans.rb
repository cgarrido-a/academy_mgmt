class AddNumberOfClassesToPaymentPlans < ActiveRecord::Migration[7.1]
  def change
    add_column :payment_plans, :number_of_classes, :integer
  end
end
