class TransbankController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:callback]

  # GET/POST /transbank/callback
  # This is called by Transbank after payment
  def callback
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
      tx = Transbank::Webpay::WebpayPlus::Transaction.new(
        commerce_code: TransbankConfig.commerce_code,
        api_key: TransbankConfig.api_key,
        environment: TransbankConfig.environment
      )
      response = tx.commit(token)

      # Check if transaction was approved
      if response['response_code'] == 0
        # Transaction approved
        payment = transaction_record.mark_as_authorized!(response)

        Rails.logger.info "Payment successfully processed: #{payment.id}"

        redirect_to success_transbank_result_path(transaction_id: transaction_record.id)
      else
        # Transaction rejected
        transaction_record.mark_as_failed!("Código de respuesta: #{response['response_code']}")

        Rails.logger.warn "Payment failed: #{response.inspect}"

        redirect_to failure_transbank_result_path(transaction_id: transaction_record.id)
      end

    rescue StandardError => e
      Rails.logger.error "Error processing Transbank callback: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      transaction_record.mark_as_failed!(e.message)

      redirect_to failure_transbank_result_path(transaction_id: transaction_record.id)
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

  def redirect_to_result(transaction_record)
    if transaction_record.authorized?
      redirect_to success_transbank_result_path(transaction_id: transaction_record.id)
    else
      redirect_to failure_transbank_result_path(transaction_id: transaction_record.id)
    end
  end
end
