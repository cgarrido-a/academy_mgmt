class WeeklyPlan < ApplicationRecord
  # Associations
  has_many :enrollments

  # Validations
  validates :plan, presence: true
  validates :description, presence: true
  validates :price, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :enrollment_fee, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weekly_classes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :number_of_classes, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
