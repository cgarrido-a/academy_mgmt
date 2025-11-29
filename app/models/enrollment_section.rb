class EnrollmentSection < ApplicationRecord
  # Associations
  belongs_to :enrollment
  belongs_to :section

  # Validations
  validates :enrollment, presence: true
  validates :section, presence: true
  validates :date, presence: true
  validates :enrollment_id, uniqueness: { scope: [:section_id, :date], message: "ya está inscrito en esta sección para esta fecha" }
  validate :section_has_available_places_for_date

  private

  def section_has_available_places_for_date
    return if section.blank? || date.blank?

    unless section.has_available_places_for_date?(date)
      errors.add(:section, "no tiene cupos disponibles para la fecha #{date.strftime('%d/%m/%Y')}")
    end
  end
end
