class Payment < ApplicationRecord
  # Associations
  belongs_to :enrollment
  belongs_to :payment_method
  belongs_to :processed_by, class_name: 'User', optional: true

  # Enums
  enum payment_type: {
    enrollment_fee: 'enrollment_fee'
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

  # Scopes
  scope :enrollment_fees, -> { where(payment_type: 'enrollment_fee') }
  scope :completed, -> { where(status: 'completed') }
  scope :recent, -> { order(payment_date: :desc) }
end
