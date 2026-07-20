# Registro de una sesión de clase suspendida (una sección en una fecha concreta).
# Cada EnrollmentSection reprogramada por esta suspensión la referencia vía
# class_suspension_id, para poder mostrar "reprogramada desde <original_date>" e historial.
class ClassSuspension < ApplicationRecord
  belongs_to :section
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :enrollment_sections, dependent: :nullify

  validates :original_date, presence: true
end
