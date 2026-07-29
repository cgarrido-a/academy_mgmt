class Course < ApplicationRecord
  # Associations
  has_many :sections, dependent: :destroy
  # Al eliminar un curso, los planes quedan sin curso (no se borran).
  has_many :weekly_plans, dependent: :nullify

  # Validations
  validates :title, presence: true
  validates :description, presence: true

  # Solo los cursos activos aceptan inscripción desde el front público.
  scope :active, -> { where(active: true) }

  # Plan "base" del curso: el regular de menor cantidad de clases (frecuencia 1x).
  # Su precio/clase, sin el descuento del tramo, es el precio base por clase del curso.
  def base_plan
    weekly_plans.where(event_type: nil).where.not(number_of_classes: nil)
                .order(:number_of_classes).first
  end

  # Precio base por clase (sin descuento). Todos los precios se derivan de esto:
  # precio = base_price_per_class × total_clases × (1 − ClassDiscount.discount_for(total_clases)).
  # @param saturday [Boolean] usa el precio de sábado del plan base si corresponde.
  def base_price_per_class(saturday: false)
    plan = base_plan
    return nil if plan.nil? || plan.number_of_classes.to_i <= 0

    monthly = saturday ? (plan.saturday_price || plan.price) : plan.price
    return nil if monthly.nil?

    base_disc = ClassDiscount.discount_for(plan.number_of_classes)
    monthly.to_f / plan.number_of_classes / (1 - base_disc / 100.0)
  end
end
