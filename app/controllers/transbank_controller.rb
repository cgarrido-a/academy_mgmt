class TransbankController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:callback]

  # GET/POST /transbank/callback
  # This is called by Transbank after payment
  def callback
    # Log all parameters received from Transbank
    Rails.logger.info "=" * 80
    Rails.logger.info "Transbank Callback - Parámetros recibidos:"
    Rails.logger.info "token_ws: #{params[:token_ws]}"
    Rails.logger.info "TBK_TOKEN: #{params[:TBK_TOKEN]}"
    Rails.logger.info "TBK_ID_SESION: #{params[:TBK_ID_SESION]}"
    Rails.logger.info "TBK_ORDEN_COMPRA: #{params[:TBK_ORDEN_COMPRA]}"
    Rails.logger.info "Todos los params: #{params.inspect}"
    Rails.logger.info "=" * 80

    # Handle user cancellation or timeout
    if params[:TBK_ORDEN_COMPRA].present? && params[:token_ws].blank?
      return handle_cancelled_transaction(params[:TBK_ORDEN_COMPRA], params[:TBK_ID_SESION])
    end

    token = params[:token_ws] || params[:TBK_TOKEN]

    unless token
      return render_error('Token no recibido')
    end

    # Find transaction
    transaction_record = TransbankTransaction.find_by(token: token)

    unless transaction_record
      return render_error('Transacción no encontrada')
    end

    # If already processed, show result
    if transaction_record.status != 'pending'
      return redirect_to_result(transaction_record)
    end

    begin
      # Commit the transaction with Transbank
      require 'ostruct'

      options = OpenStruct.new(
        commerce_code: TransbankConfig.commerce_code,
        api_key: TransbankConfig.api_key,
        environment: TransbankConfig.environment,
        timeout: 15000
      )

      tx = Transbank::Webpay::WebpayPlus::Transaction.new(options)
      response = tx.commit(token)

      # Check if transaction was approved
      if response['response_code'] == 0
        # Transaction approved - this will create enrollment(s) if they don't exist.
        #
        # OJO: desde acá para abajo la plata YA ESTÁ COBRADA. Si la creación de la
        # matrícula falla, no se puede tratar como un pago fallido (ver el rescue de
        # abajo): hay que dejar registro, avisar y poder reprocesar.
        begin
          payments = transaction_record.mark_as_authorized!(response)
        rescue StandardError => e
          return handle_authorized_but_not_enrolled(transaction_record, response, e)
        end

        if transaction_record.needs_review?
          Rails.logger.warn "Matrícula creada con fechas completadas: #{transaction_record.error_message}"
          notify_admins(transaction_record, transaction_record.error_message)
        end

        # Log payment info (handle both single and multiple payments)
        if payments.is_a?(Array)
          Rails.logger.info "Payments successfully processed: #{payments.map(&:id).join(', ')}"
          Rails.logger.info "Enrollments created: #{payments.map { |p| p.enrollment_id }.join(', ')}"
        else
          Rails.logger.info "Payment successfully processed: #{payments.id}"
          Rails.logger.info "Enrollment created: #{transaction_record.enrollment_id}" if transaction_record.enrollment_id.present?
        end

        # Enviar correo de confirmación por cada pago (una matrícula por correo).
        # Se hace fuera de la transacción de mark_as_authorized! y no debe romper
        # el flujo de pago si el envío falla.
        Array(payments).each do |payment|
          begin
            PaymentMailer.confirmation(payment).deliver_later
          rescue => e
            Rails.logger.error "No se pudo encolar el correo de confirmación (payment #{payment&.id}): #{e.message}"
          end
        end

        redirect_to_frontend_success(transaction_record, payments)
      else
        # Transaction rejected
        transaction_record.mark_as_failed!("Código de respuesta: #{response['response_code']}")

        Rails.logger.warn "Payment failed: #{response.inspect}"

        redirect_to_frontend_failure(transaction_record)
      end

    rescue StandardError => e
      Rails.logger.error "Error processing Transbank callback: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      transaction_record.mark_as_failed!(e.message)

      redirect_to_frontend_failure(transaction_record)
    end
  end

  # GET /transbank/result/success
  def success
    @transaction = TransbankTransaction.find(params[:transaction_id])
    @payment = @transaction.enrollment.payments.find_by(reference_number: @transaction.authorization_code)
  end

  # GET /transbank/result/failure
  def failure
    @transaction = TransbankTransaction.find(params[:transaction_id])
  end

  private

  def render_error(message)
    render plain: message, status: :bad_request
  end

  # Transbank cobró pero no pudimos crear la matrícula.
  # La alumna NO puede ver "pago fallido" (fue lo que pasó el 3-ago-2026 con $144.000):
  # se le confirma el pago avisando que falta el último paso, se deja la transacción en
  # authorized_error con la respuesta guardada para reprocesar, y se avisa a los admins.
  def handle_authorized_but_not_enrolled(transaction_record, response, error)
    Rails.logger.error "PAGO COBRADO SIN MATRÍCULA (tx #{transaction_record.id}): #{error.message}"
    Rails.logger.error error.backtrace.join("\n")

    begin
      transaction_record.record_authorized_failure!(response, error.message)
    rescue StandardError => e
      # Si ni esto se puede guardar, al menos que quede en el log con todo lo necesario.
      Rails.logger.error "No se pudo registrar el cobro sin matrícula: #{e.message}"
      Rails.logger.error "Respuesta de Transbank: #{response.inspect}"
    end

    notify_admins(transaction_record, "COBRO SIN MATRÍCULA: #{error.message}")

    redirect_to_frontend_success(transaction_record, nil, enrollment_pending: true)
  end

  def notify_admins(transaction_record, message)
    AdminAlertMailer.transbank_incident(transaction_record, message).deliver_later
  rescue StandardError => e
    Rails.logger.error "No se pudo avisar a los admins (tx #{transaction_record.id}): #{e.message}"
  end

  def handle_cancelled_transaction(buy_order, session_id)
    Rails.logger.info "Transacción cancelada por el usuario. Buy Order: #{buy_order}, Session ID: #{session_id}"

    transaction_record = TransbankTransaction.find_by(buy_order: buy_order)

    unless transaction_record
      return render_error('Transacción no encontrada')
    end

    # Mark as failed with cancellation message
    transaction_record.mark_as_failed!('Usuario canceló el pago en Transbank')

    Rails.logger.warn "Payment cancelled by user: Buy Order #{buy_order}"

    redirect_to_frontend_failure(transaction_record)
  end

  def redirect_to_result(transaction_record)
    if transaction_record.authorized?
      # Get payments to extract enrollment IDs
      payments = transaction_record.enrollment.payments.where(reference_number: transaction_record.authorization_code)
      redirect_to_frontend_success(transaction_record, payments)
    else
      redirect_to_frontend_failure(transaction_record)
    end
  end

  # enrollment_pending: el cobro salió bien pero la matrícula quedó en revisión.
  # El front muestra "pago recibido, estamos confirmando tu matrícula".
  def redirect_to_frontend_success(transaction_record, payments = nil, enrollment_pending: false)
    # Build frontend success URL with transaction details
    frontend_url = ENV['FRONTEND_URL'] || 'http://localhost:5173'

    # Extract enrollment IDs from payments
    enrollment_ids = if payments.present?
                       payments_array = payments.is_a?(Array) ? payments : [payments]
                       payments_array.map(&:enrollment_id).uniq
                     else
                       [transaction_record.enrollment_id].compact
                     end

    query = {
      enrollment_ids: enrollment_ids.join(','),
      transaction_id: transaction_record.id,
      buy_order: transaction_record.buy_order,
      amount: transaction_record.amount,
      authorization_code: transaction_record.authorization_code
    }
    query[:enrollment_pending] = 1 if enrollment_pending

    redirect_url = "#{frontend_url}/payment/success?" + query.to_query

    redirect_to redirect_url, allow_other_host: true
  end

  def redirect_to_frontend_failure(transaction_record)
    # Build frontend failure URL with transaction details
    frontend_url = ENV['FRONTEND_URL'] || 'http://localhost:5173'

    redirect_url = "#{frontend_url}/payment/failure?" + {
      enrollment_id: transaction_record.enrollment_id,
      transaction_id: transaction_record.id,
      buy_order: transaction_record.buy_order,
      error: transaction_record.error_message || 'Pago rechazado'
    }.to_query

    redirect_to redirect_url, allow_other_host: true
  end
end
