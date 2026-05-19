class EnrollmentSection < ApplicationRecord
  KINDS = %w[regular makeup].freeze

  # Associations
  belongs_to :enrollment
  belongs_to :section
  belongs_to :makes_up_for, class_name: 'EnrollmentSection', optional: true
  has_one    :makeup,       class_name: 'EnrollmentSection', foreign_key: 'makes_up_for_id', dependent: :nullify

  # Validations
  validates :enrollment, presence: true
  validates :section, presence: true
  validates :date, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :enrollment_id, uniqueness: { scope: [:section_id, :date], message: "ya está inscrito en esta sección para esta fecha" }
  validate :section_has_available_places_for_date
  validate :makeup_origin_is_an_absence
  validate :makeup_belongs_to_same_enrollment

  # Scopes
  scope :regular, -> { where(kind: 'regular') }
  scope :makeup,  -> { where(kind: 'makeup') }

  def regular?
    kind == 'regular'
  end

  def makeup?
    kind == 'makeup'
  end

  private

  def section_has_available_places_for_date
    return if section.blank? || date.blank?

    unless section.has_available_places_for_date?(date)
      errors.add(:section, "no tiene cupos disponibles para la fecha #{date.strftime('%d/%m/%Y')}")
    end
  end

  def makeup_origin_is_an_absence
    return unless makeup?

    if makes_up_for.blank?
      errors.add(:makes_up_for, 'es obligatorio para un recuperatorio')
      return
    end

    unless makes_up_for.attended == false
      errors.add(:makes_up_for, 'sólo se puede asignar un recuperatorio a una falta confirmada')
    end
  end

  def makeup_belongs_to_same_enrollment
    return if makes_up_for.blank?

    if makes_up_for.enrollment_id != enrollment_id
      errors.add(:makes_up_for, 'debe pertenecer al mismo estudiante (misma inscripción)')
    end
  end
end
