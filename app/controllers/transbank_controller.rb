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
        # Transaction approved - this will create enrollment(s) if they don't exist
        payments = transaction_record.mark_as_authorized!(response)

        # Log payment info (handle both single and multiple payments)
        if payments.is_a?(Array)
          Rails.logger.info "Payments successfully processed: #{payments.map(&:id).join(', ')}"
          Rails.logger.info "Enrollments created: #{payments.map { |p| p.enrollment_id }.join(', ')}"
        else
          Rails.logger.info "Payment successfully processed: #{payments.id}"
          Rails.logger.info "Enrollment created: #{transaction_record.enrollment_id}" if transaction_record.enrollment_id.present?
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

  def redirect_to_frontend_success(transaction_record, payments = nil)
    # Build frontend success URL with transaction details
    frontend_url = ENV['FRONTEND_URL'] || 'http://localhost:5173'

    # Extract enrollment IDs from payments
    enrollment_ids = if payments.present?
                       payments_array = payments.is_a?(Array) ? payments : [payments]
                       payments_array.map(&:enrollment_id).uniq
                     else
                       [transaction_record.enrollment_id].compact
                     end

    redirect_url = "#{frontend_url}/payment/success?" + {
      enrollment_ids: enrollment_ids.join(','),
      transaction_id: transaction_record.id,
      buy_order: transaction_record.buy_order,
      amount: transaction_record.amount,
      authorization_code: transaction_record.authorization_code
    }.to_query

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
