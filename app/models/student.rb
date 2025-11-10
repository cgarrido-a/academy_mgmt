class Student < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :enrollments, dependent: :destroy

  # Validations
  validates :user, presence: true
end
