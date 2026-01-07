class Enrollment < ApplicationRecord
  # Associations
  belongs_to :student
  belongs_to :weekly_plan
  belongs_to :payment_method
  has_many :enrollment_sections, dependent: :destroy
  has_many :sections, through: :enrollment_sections
  has_many :payments, dependent: :destroy
  has_many :transbank_transactions, dependent: :destroy

  # Validations
  validates :student, presence: true
  validates :weekly_plan, presence: true
  validates :payment_method, presence: true
  validates :enrollment_amount, presence: true, numericality: { greater_than: 0 }
  validates :total_tuition_fee, presence: true, numericality: { greater_than: 0 }

  # Helper methods for payments
  def enrollment_fee_payment
    payments.enrollment_fees.first
  end

  def enrollment_fee_paid?
    enrollment_fee_payment.present?
  end

  def total_paid
    payments.completed.sum(:amount)
  end
end
