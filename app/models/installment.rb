class Installment < ApplicationRecord
  # Associations
  belongs_to :tuition_fee
  has_many :payments, dependent: :destroy

  # Validations
  validates :tuition_fee, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :due_date, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending paid overdue] }

  # Defaults
  after_initialize :set_default_status, if: :new_record?

  # Helper methods for payments
  def total_paid
    payments.completed.sum(:amount)
  end

  def remaining_amount
    amount - total_paid
  end

  def fully_paid?
    total_paid >= amount
  end

  def partially_paid?
    total_paid > 0 && !fully_paid?
  end

  # Auto-update status based on payments
  def update_payment_status!
    if fully_paid?
      update(status: 'paid', payment_date: payments.completed.maximum(:payment_date))
    elsif due_date < Date.today && !fully_paid?
      update(status: 'overdue')
    else
      update(status: 'pending')
    end
  end

  private

  def set_default_status
    self.status ||= 'pending'
  end
end
