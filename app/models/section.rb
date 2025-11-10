class Section < ApplicationRecord
  # Associations
  belongs_to :course
  belongs_to :teacher
  has_many :enrollments, dependent: :destroy

  # Validations
  validates :course, presence: true
  validates :teacher, presence: true
  validates :places, presence: true, numericality: { greater_than: 0 }
  validates :schedule, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  # Instance methods
  def available_places
    places - enrollments.count
  end

  def has_available_places?
    available_places > 0
  end

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date < start_date
      errors.add(:end_date, "must be after the start date")
    end
  end
end
