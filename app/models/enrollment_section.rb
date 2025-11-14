class EnrollmentSection < ApplicationRecord
  # Associations
  belongs_to :enrollment
  belongs_to :section

  # Validations
  validates :enrollment, presence: true
  validates :section, presence: true
  validates :enrollment_id, uniqueness: { scope: :section_id, message: "ya está inscrito en esta sección" }
  validate :section_has_available_places

  private

  def section_has_available_places
    return if section.blank?

    unless section.has_available_places?
      errors.add(:section, "has no available places")
    end
  end
end
