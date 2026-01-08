class WeeklyPlan < ApplicationRecord
  # Associations
  has_many :enrollments

  # Validations
  validates :plan, presence: true
  validates :description, presence: true
  validates :price, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :enrollment_fee, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weekly_classes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :number_of_classes, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Calculate final price with discount applied
  # @param payment_period [PaymentPeriod] The payment period to apply discount from
  # @return [Integer] The final price with discount applied
  def calculate_final_price(payment_period)
    return price if payment_period.nil? || price.nil?

    discount_multiplier = 1 - (payment_period.discount_percentage / 100.0)
    (price * discount_multiplier).round
  end
end
