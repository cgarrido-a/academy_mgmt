class WeeklyPlan < ApplicationRecord
  # Associations
  has_many :enrollments

  # Validations
  validates :plan, presence: true
  validates :description, presence: true
  validates :price, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :saturday_price, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :enrollment_fee, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weekly_classes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :number_of_classes, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Calculate final price with discount applied
  # @param payment_period [PaymentPeriod] The payment period to apply discount from
  # @param section_ids [Array<Integer>] Optional array of section IDs to check for Saturday pricing
  # @return [Integer] The final price with discount applied
  def calculate_final_price(payment_period, section_ids: nil)
    base_price = determine_base_price(section_ids)
    return base_price if payment_period.nil? || base_price.nil?

    discount_multiplier = 1 - (payment_period.discount_percentage / 100.0)
    (base_price * discount_multiplier).round
  end

  private

  # Determine the base price based on whether sections are on Saturday
  # @param section_ids [Array<Integer>] Optional array of section IDs
  # @return [Integer] The base price (saturday_price if applicable, otherwise price)
  def determine_base_price(section_ids)
    # If no sections provided, use regular price
    return price if section_ids.blank?

    # Check if any section is on Saturday
    sections = Section.where(id: section_ids)
    has_saturday_section = sections.any? { |section| section.weekday == 'Sábado' }

    # Use saturday_price if available and sections are on Saturday, otherwise use regular price
    if has_saturday_section && saturday_price.present?
      saturday_price
    else
      price
    end
  end
end
