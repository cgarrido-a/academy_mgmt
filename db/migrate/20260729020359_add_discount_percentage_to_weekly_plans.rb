class AddDiscountPercentageToWeeklyPlans < ActiveRecord::Migration[7.1]
  # Descuento "real" que el plan ya trae incorporado en su precio (ej: un plan
  # de mayor frecuencia cuesta menos por clase que el base). Es solo para
  # MOSTRAR en el front (badge). No recalcula el precio: el precio ya lo incluye.
  def change
    add_column :weekly_plans, :discount_percentage, :integer
  end
end
