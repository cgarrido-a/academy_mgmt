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

  # Calculate final price con el modelo GLOBAL por cantidad de clases:
  #   precio = precio_base_por_clase(curso) × total_clases × (1 − dcto(total_clases))
  # donde total_clases = number_of_classes × meses y el descuento sale de ClassDiscount
  # (el tramo con el mayor number_of_classes <= total_clases). El período (meses) solo
  # define cuántas clases se compran; NO aporta descuento propio. A 1 mes el precio
  # coincide con el precio mensual del plan (no cambia nada).
  #
  # @param payment_period [PaymentPeriod] define los meses (su discount_percentage ya no se usa)
  # @param section_ids [Array<Integer>] para detectar precio de sábado
  # @param saturday [Boolean, nil] fuerza el precio de sábado; si es nil se detecta de section_ids
  # @return [Integer] The final price with discount applied
  def calculate_final_price(payment_period, section_ids: [], saturday: nil)
    months = (payment_period&.months || 1)
    sat = saturday.nil? ? has_saturday_section?(section_ids) : saturday

    base_per_class = course&.base_price_per_class(saturday: sat)
    # Fallback al precio mensual si no se puede determinar la base por clase.
    return determine_base_price(section_ids) if base_per_class.nil? || number_of_classes.nil?

    total_classes = number_of_classes * months
    discount = ClassDiscount.discount_for(total_classes)
    (base_per_class * total_classes * (1 - discount / 100.0)).round
  end

  # Determine the base price based on whether sections are on Saturday
  # @param section_ids [Array<Integer>] Array of section IDs
  # @return [Integer] The base price (saturday_price if sections are on Saturday, otherwise price)
  def determine_base_price(section_ids)
    # If no sections provided, cannot determine price by day, return regular price as default
    return price if section_ids.blank?

    # Use saturday_price if sections are on Saturday, otherwise use regular price
    if has_saturday_section?(section_ids)
      saturday_price || price # Fallback to price if saturday_price not set
    else
      price
    end
  end

  # ¿Alguna de las secciones dadas es de sábado?
  def has_saturday_section?(section_ids)
    return false if section_ids.blank?

    Section.where(id: section_ids).any? { |section| section.weekday == 'Sábado' }
  end
end
