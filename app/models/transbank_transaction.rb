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

  # Create enrollment from stored enrollment_data
  def create_enrollment_from_data!
    raise 'Enrollment already exists' if enrollment_id.present?
    raise 'No enrollment data present' if enrollment_data.blank?

    data = enrollment_data.with_indifferent_access

    # Use EnrollmentCreator to create the enrollment
    creator = EnrollmentCreator.new(data)

    if creator.call
      # Update this transaction with the created enrollment
      update!(enrollment: creator.enrollment)
      creator.enrollment
    else
      raise "Failed to create enrollment: #{creator.errors.join(', ')}"
    end
  end

  # Mark transaction as authorized and create payment record
  def mark_as_authorized!(transbank_response)
    transaction do
      # Create enrollment if it doesn't exist yet (from pending enrollment_data)
      create_enrollment_from_data! if enrollment_id.blank? && enrollment_data.present?

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

      # Create Payment record
      payment = Payment.create!(
        enrollment: enrollment,
        payment_type: payment_type,
        amount: amount,
        payment_date: Date.today,
        payment_method: PaymentMethod.find_or_create_by!(payment_method: 'Transbank Webpay'),
        reference_number: authorization_code,
        notes: "Pago automático vía Transbank. Buy Order: #{buy_order}",
        status: 'completed'
      )

      payment
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
