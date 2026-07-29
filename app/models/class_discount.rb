class ClassDiscount < ApplicationRecord
  validates :number_of_classes, presence: true,
            numericality: { only_integer: true, greater_than: 0 },
            uniqueness: true
  validates :discount_percentage, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  # Descuento (%) para una cantidad total de clases: toma el tramo con el mayor
  # number_of_classes que no supere a `total_classes`. Si no hay ninguno <=, 0%.
  def self.discount_for(total_classes)
    return 0 if total_classes.nil? || total_classes <= 0

    where("number_of_classes <= ?", total_classes)
      .order(number_of_classes: :desc)
      .limit(1)
      .pick(:discount_percentage) || 0
  end
end
