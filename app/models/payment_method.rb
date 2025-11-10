class PaymentMethod < ApplicationRecord
  # Associations
  has_many :enrollments
  has_many :tuition_fees
  has_many :salary_payments

  # Validations
  validates :payment_method, presence: true, uniqueness: true
end
