class PaymentMethod < ApplicationRecord
  # Associations
  has_many :enrollments
  has_many :salary_payments
  has_many :payments

  # Validations
  validates :payment_method, presence: true, uniqueness: true
end
