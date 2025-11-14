class Payment < ApplicationRecord
  # Associations
  belongs_to :enrollment
  belongs_to :installment, optional: true
  belongs_to :payment_method
  belongs_to :processed_by, class_name: 'User', optional: true

  # Enums
  enum payment_type: {
    enrollment_fee: 'enrollment_fee',
    installment: 'installment'
  }

  enum status: {
    completed: 'completed',
    pending: 'pending',
    refunded: 'refunded'
  }

  # Validations
  validates :enrollment, presence: true
  validates :payment_type, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_date, presence: true
  validates :payment_method, presence: true
  validates :status, presence: true

  # Validate that installment payments must have an installment_id
  validate :installment_payment_must_have_installment

  # Scopes
  scope :enrollment_fees, -> { where(payment_type: 'enrollment_fee') }
  scope :installment_payments, -> { where(payment_type: 'installment') }
  scope :completed, -> { where(status: 'completed') }
  scope :recent, -> { order(payment_date: :desc) }

  private

  def installment_payment_must_have_installment
    if payment_type == 'installment' && installment_id.blank?
      errors.add(:installment_id, "debe estar presente para pagos de cuotas")
    end
  end
end
