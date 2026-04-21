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
    places - enrollments.distinct.count
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

    entry = schedule.first
    "#{entry['start_time']}-#{entry['end_time']}"
  end

  WEEKDAY_TO_WDAY = {
    'Domingo' => 0, 'Lunes' => 1, 'Martes' => 2, 'Miércoles' => 3,
    'Jueves' => 4, 'Viernes' => 5, 'Sábado' => 6
  }.freeze

  def class_dates
    enrollment_sections.select(:date).distinct.pluck(:date).to_set
  end

  def attendance_counts_by_date
    enrollment_sections
      .group(:date)
      .pluck(:date, Arel.sql('COUNT(*)'), Arel.sql('COUNT(CASE WHEN attended = true THEN 1 END)'))
      .each_with_object({}) { |(d, t, p), h| h[d] = { total: t, present: p } }
  end

  def calendar_weeks_for(month_date, selected_date: nil, class_dates_set: nil)
    first_day = month_date.beginning_of_month
    last_day = month_date.end_of_month
    start_date = first_day.beginning_of_week(:monday)
    end_date = last_day.end_of_week(:monday)

    dates = class_dates_set || class_dates
    section_wday = WEEKDAY_TO_WDAY[weekday]

    weeks = []
    current = start_date
    while current <= end_date
      weeks << (0..6).map do |i|
        day = current + i
        {
          date: day,
          in_month: day.month == month_date.month,
          is_today: day == Date.current,
          has_class: dates.include?(day),
          is_section_day: day.wday == section_wday,
          is_selected: day == selected_date
        }
      end
      current += 7
    end
    weeks
  end

  private

  def schedule_format
    return if schedule.blank?

    unless schedule.is_a?(Array)
      errors.add(:schedule, "debe ser un arreglo")
      return
    end

    if schedule.empty?
      errors.add(:schedule, "debe tener un horario")
      return
    end

    if schedule.length > 1
      errors.add(:schedule, "solo puede tener un horario por sección")
      return
    end

    entry = schedule.first

    unless entry.is_a?(Hash)
      errors.add(:schedule, "debe ser un objeto válido")
      return
    end

    unless entry['start_time'].present?
      errors.add(:schedule, "debe tener hora de inicio")
    end

    unless entry['end_time'].present?
      errors.add(:schedule, "debe tener hora de fin")
    end

    # Validate time format (HH:MM)
    if entry['start_time'].present? && !entry['start_time'].match?(/^\d{2}:\d{2}$/)
      errors.add(:schedule, "hora de inicio debe estar en formato HH:MM")
    end

    if entry['end_time'].present? && !entry['end_time'].match?(/^\d{2}:\d{2}$/)
      errors.add(:schedule, "hora de fin debe estar en formato HH:MM")
    end
  end
end
