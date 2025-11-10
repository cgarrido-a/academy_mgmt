class Course < ApplicationRecord
  # Associations
  has_many :sections, dependent: :destroy

  # Validations
  validates :title, presence: true
  validates :description, presence: true
end
