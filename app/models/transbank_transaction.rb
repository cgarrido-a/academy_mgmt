class TransbankTransaction < ApplicationRecord
  # Prefijo de las notas que exigen mirada humana (se muestran en el panel admin).
  REVIEW_PREFIX = '[REVISAR]'.freeze

  # Fechas que hubo que completar solas al crear la matrícula (ver EnrollmentCreator).
  attr_reader :autocompleted_dates

  # Associations
  belongs_to :enrollment, optional: true

  # Enums
  enum payment_type: {
    enrollment_fee: 'enrollment_fee'
  }

  # authorized_error = Transbank COBRÓ pero no pudimos crear la matrícula.
  # Es distinto de failed (rechazo sin plata de por medio) justamente porque acá sí
  # hay plata capturada: son las que hay que reprocesar, nunca dejarlas pasar.
  enum status: {
    pending: 'pending',
    authorized: 'authorized',
    failed: 'failed',
    nullified: 'nullified',
    authorized_error: 'authorized_error'
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
  # Cobradas que necesitan mirada humana: sin matrícula, o con fechas completadas solas.
  scope :needs_review, lambda {
    where(status: 'authorized_error').or(where('error_message LIKE ?', "#{REVIEW_PREFIX}%"))
  }

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
    # Use EnrollmentCreator to create the enrollment.
    # allow_autocomplete: acá ya se cobró, así que si faltan fechas se completan en
    # vez de dejar a la alumna sin matrícula (la validación estricta va antes del pago).
    creator = EnrollmentCreator.new(data, allow_autocomplete: true)

    if creator.call
      @autocompleted_dates = creator.autocompleted_dates
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
      creator = EnrollmentCreator.new(enrollment_data.with_indifferent_access, allow_autocomplete: true)

      if creator.call
        created_enrollments << creator.enrollment
        @autocompleted_dates = (@autocompleted_dates || []) + creator.autocompleted_dates
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
        raw_response: transbank_response.to_json,
        error_message: review_note
      )

      # Create Payment record(s) - one for each enrollment
      payments = []
      enrollments_to_process = created_enrollments || [enrollment]

      enrollments_to_process.each do |enr|
        payment = Payment.create!(
          enrollment: enr,
          payment_type: payment_type,
          amount: enr.total_tuition_fee,
          # La fecha del pago es la del cobro en Transbank, no la de hoy: si esto se
          # reprocesa días después, Date.today dejaría el comprobante con fecha falsa.
          payment_date: (transaction_date || Time.current).to_date,
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

  # Transbank aprobó y cobró, pero la matrícula no se pudo crear.
  #
  # Guarda TODO lo que devolvió Transbank (fuera de la transacción que se revirtió)
  # para poder reprocesar después sin tener que ir a preguntarle a Transbank — que
  # además sólo responde 7 días hacia atrás. NO usa 'failed' a propósito: ese estado
  # significa "no hay plata de por medio" y fue lo que dejó invisible el cobro de la
  # transacción 140.
  def record_authorized_failure!(transbank_response, error)
    card = transbank_response['card_detail'].is_a?(Hash) ? transbank_response['card_detail']['card_number'] : nil
    fecha = begin
      transbank_response['transaction_date'].present? ? DateTime.parse(transbank_response['transaction_date']) : nil
    rescue StandardError
      nil
    end

    update!(
      status: 'authorized_error',
      authorization_code: transbank_response['authorization_code'],
      payment_type_code: transbank_response['payment_type_code'],
      response_code: transbank_response['response_code'],
      card_number: card,
      transaction_date: fecha,
      raw_response: transbank_response.to_json,
      error_message: "#{REVIEW_PREFIX} COBRADO SIN MATRÍCULA. #{error}"
    )
  end

  # Reintenta la creación de la matrícula con la respuesta de Transbank ya guardada.
  # Es lo que usa el botón "Reprocesar" del panel admin.
  def reprocess!
    raise 'Esta transacción no tiene la respuesta de Transbank guardada' if raw_response.blank?
    raise 'Esta transacción ya tiene matrícula creada' if enrollment_id.present?

    mark_as_authorized!(JSON.parse(raw_response))
  end

  def needs_review?
    error_message.to_s.start_with?(REVIEW_PREFIX)
  end

  private

  # Nota para el panel admin cuando la matrícula se creó pero con fechas completadas
  # automáticamente (el front mandó menos de las que corresponden al plan).
  def review_note
    return nil if autocompleted_dates.blank?

    detalle = autocompleted_dates.map { |d| "#{d[:date]} (sección #{d[:section_id]})" }.join(', ')
    "#{REVIEW_PREFIX} Se completaron #{autocompleted_dates.size} clase(s) que el front no envió: #{detalle}"
  end
end
