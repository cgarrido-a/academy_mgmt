# Reglas de funcionamiento de la academia, editables desde el admin (una sola fila).
# 0 en un campo desactiva esa regla.
class BusinessRule < ApplicationRecord
  validates :max_days_ahead_for_start, :seat_hold_days,
            presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # La fila vigente. Si la tabla todavía no existe (deploy antes de migrar) o quedó
  # vacía, devuelve los valores por defecto sin guardar, para no botar la inscripción.
  def self.current
    first || new
  rescue ActiveRecord::StatementInvalid
    new
  end

  # Última fecha de inicio que acepta la web pública (nil = sin límite).
  def max_start_date(today = Date.current)
    return nil if max_days_ahead_for_start.to_i.zero?

    today + max_days_ahead_for_start.days
  end
end
