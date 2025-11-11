class TuitionFee < ApplicationRecord
  # Associations
  belongs_to :enrollment
  belongs_to :payment_method
  has_many :installments, dependent: :destroy

  # Validations
  validates :enrollment, presence: true
  validates :payment_method, presence: true
  validates :total_tuition_fee, presence: true, numericality: { greater_than: 0 }
  validates :instalments_number, presence: true, numericality: { greater_than: 0 }
  validates :billing_period, presence: true
end
