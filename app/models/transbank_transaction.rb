class TransbankTransaction < ApplicationRecord
  # Associations
  belongs_to :enrollment, optional: true

  # Enums
  enum payment_type: {
    enrollment_fee: 'enrollment_fee'
  }

  enum status: {
    pending: 'pending',
    authorized: 'authorized',
    failed: 'failed',
    nullified: 'nullified'
  }

  # Validations
  validates :payment_type, presence: true
  validates :token, presence: true, uniqueness: true
  validates :buy_order, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validate :enrollment_or_data_present

  def enrollment_or_data_present
    if enrollment_id.blank? && enrollment_data.blank?
      errors.add(:base, 'Must have either enrollment_id or enrollment_data')
    end
  end

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :authorized, -> { where(status: 'authorized') }
  scope :recent, -> { order(created_at: :desc) }

  # Generate a unique buy order
  def self.generate_buy_order(identifier, payment_type)
    timestamp = Time.now.to_i
    "ENR#{identifier}-FEE-#{timestamp}"
  end

  # Create enrollment(s) from stored enrollment_data
  def create_enrollment_from_data!
    raise 'Enrollment already exists' if enrollment_id.present?
    raise 'No enrollment data present' if enrollment_data.blank?

    data = enrollment_data.with_indifferent_access

    # Check if we have multiple enrollments or a single enrollment
    if data[:enrollments].present?
      # Multiple enrollments case
      create_multiple_enrollments!(data[:enrollments])
    else
      # Single enrollment case (backwards compatibility)
      create_single_enrollment!(data)
    end
  end

  private

  def create_single_enrollment!(data)
    # Use EnrollmentCreator to create the enrollment
    creator = EnrollmentCreator.new(data)

    if creator.call
      # Update this transaction with the created enrollment
      update!(enrollment: creator.enrollment)
      [creator.enrollment] # Return as array for consistency
    else
      raise "Failed to create enrollment: #{creator.errors.join(', ')}"
    end
  end

  def create_multiple_enrollments!(enrollments_data)
    created_enrollments = []
    errors = []

    enrollments_data.each_with_index do |enrollment_data, index|
      creator = EnrollmentCreator.new(enrollment_data.with_indifferent_access)

      if creator.call
        created_enrollments << creator.enrollment
      else
        errors << "Enrollment #{index + 1}: #{creator.errors.join(', ')}"
      end
    end

    if errors.any?
      raise "Failed to create some enrollments: #{errors.join('; ')}"
    end

    # Update this transaction with the first enrollment as reference
    update!(enrollment: created_enrollments.first) if created_enrollments.any?

    created_enrollments
  end

  public

  # Mark transaction as authorized and create payment record(s)
  def mark_as_authorized!(transbank_response)
    transaction do
      # Create enrollment(s) if it doesn't exist yet (from pending enrollment_data)
      created_enrollments = create_enrollment_from_data! if enrollment_id.blank? && enrollment_data.present?

      # Extract card number (last 4 digits) from card_detail
      card_number = if transbank_response['card_detail'].is_a?(Hash)
                     transbank_response['card_detail']['card_number']
                   else
                     nil
                   end

      # Parse transaction date
      transaction_date = if transbank_response['transaction_date'].present?
                          begin
                            DateTime.parse(transbank_response['transaction_date'])
                          rescue
                            nil
                          end
                        else
                          nil
                        end

      update!(
        status: 'authorized',
        authorization_code: transbank_response['authorization_code'],
        payment_type_code: transbank_response['payment_type_code'],
        response_code: transbank_response['response_code'],
        card_number: card_number,
        transaction_date: transaction_date,
        raw_response: transbank_response.to_json
      )

      # Create Payment record(s) - one for each enrollment
      payments = []
      enrollments_to_process = created_enrollments || [enrollment]

      enrollments_to_process.each do |enr|
        payment = Payment.create!(
          enrollment: enr,
          payment_type: payment_type,
          amount: enr.total_tuition_fee,
          payment_date: Date.today,
          payment_method: enr.payment_method,
          reference_number: authorization_code,
          notes: "Pago automático vía Transbank. Buy Order: #{buy_order}",
          status: 'completed'
        )
        payments << payment
      end

      payments.size == 1 ? payments.first : payments
    end
  end

  # Mark transaction as failed
  def mark_as_failed!(error_message = nil)
    update!(
      status: 'failed',
      error_message: error_message
    )
  end
end
