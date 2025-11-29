class Section < ApplicationRecord
  # Serialize schedule as JSON
  serialize :schedule, coder: JSON

  # Associations
  belongs_to :course
  belongs_to :teacher
  has_many :enrollment_sections, dependent: :destroy
  has_many :enrollments, through: :enrollment_sections

  # Validations
  validates :course, presence: true
  validates :teacher, presence: true
  validates :places, presence: true, numericality: { greater_than: 0 }
  validates :weekday, presence: true
  validate :schedule_format

  # Instance methods
  def available_places
    places - enrollments.count
  end

  def has_available_places?
    available_places > 0
  end

  # Calculate available places for a specific date
  def available_places_for_date(date)
    enrolled_count = enrollment_sections.where(date: date).count
    places - enrolled_count
  end

  def has_available_places_for_date?(date)
    available_places_for_date(date) > 0
  end

  # Format schedule for display
  def formatted_schedule
    return "Sin horario definido" if schedule.blank? || schedule.empty?

    schedule.map do |entry|
      "#{entry['start_time']}-#{entry['end_time']}"
    end.join(', ')
  end

  private

  def schedule_format
    return if schedule.blank?

    unless schedule.is_a?(Array)
      errors.add(:schedule, "debe ser un arreglo")
      return
    end

    if schedule.empty?
      errors.add(:schedule, "debe tener al menos un horario")
      return
    end

    schedule.each_with_index do |entry, index|
      unless entry.is_a?(Hash)
        errors.add(:schedule, "entrada #{index + 1} debe ser un objeto")
        next
      end

      unless entry['start_time'].present?
        errors.add(:schedule, "entrada #{index + 1} debe tener hora de inicio")
      end

      unless entry['end_time'].present?
        errors.add(:schedule, "entrada #{index + 1} debe tener hora de fin")
      end

      # Validate time format (HH:MM)
      if entry['start_time'].present? && !entry['start_time'].match?(/^\d{2}:\d{2}$/)
        errors.add(:schedule, "entrada #{index + 1}: hora de inicio debe estar en formato HH:MM")
      end

      if entry['end_time'].present? && !entry['end_time'].match?(/^\d{2}:\d{2}$/)
        errors.add(:schedule, "entrada #{index + 1}: hora de fin debe estar en formato HH:MM")
      end
    end
  end
end
