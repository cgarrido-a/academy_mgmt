class PaymentPeriod < ApplicationRecord
  # Validations
  validates :months, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :discount_percentage, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
end
