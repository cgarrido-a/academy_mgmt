class TransbankTransaction < ApplicationRecord
  # Associations
  belongs_to :enrollment
  belongs_to :installment, optional: true

  # Enums
  enum payment_type: {
    enrollment_fee: 'enrollment_fee',
    installment: 'installment'
  }

  enum status: {
    pending: 'pending',
    authorized: 'authorized',
    failed: 'failed',
    nullified: 'nullified'
  }

  # Validations
  validates :enrollment, presence: true
  validates :payment_type, presence: true
  validates :token, presence: true, uniqueness: true
  validates :buy_order, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true

  # Validate that installment payments must have an installment_id
  validate :installment_payment_must_have_installment

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :authorized, -> { where(status: 'authorized') }
  scope :recent, -> { order(created_at: :desc) }

  # Generate a unique buy order
  def self.generate_buy_order(enrollment_id, payment_type, installment_id = nil)
    timestamp = Time.now.to_i
    if installment_id
      "ENR#{enrollment_id}-INST#{installment_id}-#{timestamp}"
    else
      "ENR#{enrollment_id}-FEE-#{timestamp}"
    end
  end

  # Mark transaction as authorized and create payment record
  def mark_as_authorized!(transbank_response)
    transaction do
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
        installment: installment,
        payment_type: payment_type,
        amount: amount,
        payment_date: Date.today,
        payment_method: PaymentMethod.find_or_create_by!(payment_method: 'Transbank Webpay'),
        reference_number: authorization_code,
        notes: "Pago automático vía Transbank. Buy Order: #{buy_order}",
        status: 'completed'
      )

      # Update installment status if applicable
      if installment.present?
        installment.update_payment_status!
      end

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

  private

  def installment_payment_must_have_installment
    if payment_type == 'installment' && installment_id.blank?
      errors.add(:installment_id, "debe estar presente para pagos de cuotas")
    end
  end
end
