class PaymentPlan < ApplicationRecord
  # Associations
  has_many :enrollments

  # Validations
  validates :plan, presence: true, numericality: { greater_than: 0 }
  validates :description, presence: true
end
