class PaymentPlan < ApplicationRecord
  # Associations
  has_many :enrollments

  # Validations
  validates :plan, presence: true
  validates :description, presence: true
end
