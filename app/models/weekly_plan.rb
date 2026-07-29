class WeeklyPlan < ApplicationRecord
  # Associations
  # Cada plan pertenece a un curso (ej: "Mensual óleo", "Mensual acuarela").
  # optional: los planes creados antes de esta feature quedan sin curso hasta
  # que se asignen manualmente desde el panel.
  belongs_to :course, optional: true
  has_many :enrollments

  # Enums
  enum event_type: { trial: 0, special_event: 1 }

  # Validations
  validates :plan, presence: true
  validates :description, presence: true
  validates :price, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :saturday_price, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :enrollment_fee, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weekly_classes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :number_of_classes, presence: true, numericality: { only_integer: true, greater_than: 0 }
  # Descuento incorporado en el precio del plan; solo informativo (para mostrar en el front).
  validates :discount_percentage, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  # Calculate final price with discount applied.
  #
  # Modelo ADITIVO: el descuento total = descuento por frecuencia (ya incluido en el
  # precio mensual del plan) + descuento por período (extra por extender los meses).
  # Reconstruimos el precio "sin descuento" (sacándole la frecuencia al precio del plan)
  # y aplicamos (frecuencia + período) sobre esa base, de modo que los dos descuentos se
  # SUMAN. Así el precio por clase queda igual sin importar el camino (más frecuencia o
  # más meses): 8 clases valen lo mismo como 2x/semana×1 mes o 1x/semana×2 meses.
  # A 1 mes (período 0%) el precio = precio del plan (no cambia nada).
  #
  # @param payment_period [PaymentPeriod] The payment period to apply discount from
  # @param section_ids [Array<Integer>] Array of section IDs to check for Saturday pricing
  # @return [Integer] The final price with discount applied
  def calculate_final_price(payment_period, section_ids: [])
    base_price = determine_base_price(section_ids)
    return base_price if payment_period.nil? || base_price.nil?

    months = payment_period.months || 1
    freq_discount   = (discount_percentage || 0).to_f
    period_discount = payment_period.discount_percentage.to_f

    undiscounted_monthly = freq_discount < 100 ? base_price / (1 - freq_discount / 100.0) : base_price
    total_discount = (freq_discount + period_discount) / 100.0
    (undiscounted_monthly * months * (1 - total_discount)).round
  end

  # Determine the base price based on whether sections are on Saturday
  # @param section_ids [Array<Integer>] Array of section IDs
  # @return [Integer] The base price (saturday_price if sections are on Saturday, otherwise price)
  def determine_base_price(section_ids)
    # If no sections provided, cannot determine price by day, return regular price as default
    return price if section_ids.blank?

    # Check if any section is on Saturday
    sections = Section.where(id: section_ids)
    has_saturday_section = sections.any? { |section| section.weekday == 'Sábado' }

    # Use saturday_price if sections are on Saturday, otherwise use regular price
    if has_saturday_section
      saturday_price || price # Fallback to price if saturday_price not set
    else
      price
    end
  end
end
