class TeacherPayment < ApplicationRecord
  belongs_to :teacher
  belongs_to :payment_method

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :status, inclusion: { in: %w[pending paid cancelled] }

  scope :pending, -> { where(status: 'pending') }
  scope :paid, -> { where(status: 'paid') }
end
