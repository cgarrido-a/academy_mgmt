class PaymentPlan < ApplicationRecord
  # Associations
  has_many :enrollments

  # Validations
  validates :plan, presence: true
  validates :description, presence: true
  validates :weekly_classes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
