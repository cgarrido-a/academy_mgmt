class Enrollment < ApplicationRecord
  # Associations
  belongs_to :student
  belongs_to :payment_plan
  belongs_to :section
  belongs_to :payment_method
  has_one :tuition_fee, dependent: :destroy

  # Validations
  validates :student, presence: true
  validates :payment_plan, presence: true
  validates :section, presence: true
  validates :payment_method, presence: true
  validates :enrollment_amount, presence: true, numericality: { greater_than: 0 }
  validate :section_has_available_places

  private

  def section_has_available_places
    return if section.blank?

    unless section.has_available_places?
      errors.add(:section, "has no available places")
    end
  end
end
