class PaymentMethod < ApplicationRecord
  # Associations
  has_many :enrollments
  # has_many :tuition_fees # Removed: tuition_fees table no longer exists
  has_many :salary_payments

  # Validations
  validates :payment_method, presence: true, uniqueness: true
end
