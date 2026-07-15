class Course < ApplicationRecord
  # Associations
  has_many :sections, dependent: :destroy
  # Al eliminar un curso, los planes quedan sin curso (no se borran).
  has_many :weekly_plans, dependent: :nullify

  # Validations
  validates :title, presence: true
  validates :description, presence: true

  # Solo los cursos activos aceptan inscripción desde el front público.
  scope :active, -> { where(active: true) }
end
