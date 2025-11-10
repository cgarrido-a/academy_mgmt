class Installment < ApplicationRecord
  # Associations
  belongs_to :tuition_fee

  # Validations
  validates :tuition_fee, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :due_date, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending paid overdue] }

  # Defaults
  after_initialize :set_default_status, if: :new_record?

  private

  def set_default_status
    self.status ||= 'pending'
  end
end
