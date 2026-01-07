module Students
  class PaymentsController < ApplicationController
    before_action :set_student
    before_action :set_enrollment, only: [:pay_enrollment_fee]

    # GET /student/payments
    def index
      @enrollments = @student.enrollments.includes(:sections, :weekly_plan, :payment_method)
      @pending_enrollment_fees = @enrollments.reject(&:enrollment_fee_paid?)

      # Note: installments and tuition_fees tables no longer exist
      @pending_installments = []
    end

    # POST /student/payments/pay_enrollment_fee/:enrollment_id
    def pay_enrollment_fee
      if @enrollment.enrollment_fee_paid?
        render json: {
          error: 'La matrícula ya ha sido pagada.'
        }, status: :unprocessable_entity
        return
      end

      # Generate buy order
      buy_order = TransbankTransaction.generate_buy_order(@enrollment.id, 'enrollment_fee')

      # Create Transbank transaction record
      transaction_record = TransbankTransaction.create!(
        enrollment: @enrollment,
        payment_type: 'enrollment_fee',
        buy_order: buy_order,
        amount: @enrollment.total_tuition_fee,
        status: 'pending',
        token: '' # Will be updated after Transbank response
      )

      # Initialize Webpay Plus transaction
      tx = Transbank::Webpay::WebpayPlus::Transaction.new(
        commerce_code: TransbankConfig.commerce_code,
        api_key: TransbankConfig.api_key,
        environment: TransbankConfig.environment
      )
      response = tx.create(
        buy_order: buy_order,
        session_id: session.id.to_s,
        amount: @enrollment.total_tuition_fee.to_i,
        return_url: transbank_return_url
      )

      # Update transaction with token
      transaction_record.update!(token: response['token'])

      # Return Transbank URL as JSON
      render json: {
        url: response['url'],
        token: response['token'],
        full_url: "#{response['url']}?token_ws=#{response['token']}",
        buy_order: buy_order,
        amount: @enrollment.total_tuition_fee
      }, status: :ok

    rescue StandardError => e
      Rails.logger.error "Error creating Transbank transaction: #{e.message}"
      render json: {
        error: "Error al procesar el pago: #{e.message}"
      }, status: :internal_server_error
    end   

    private

    def set_student
      # TODO: Replace with actual authentication
      # For now, get student from params or session
      @student = Student.find(params[:student_id] || session[:student_id] || 1)
    end

    def set_enrollment
      @enrollment = @student.enrollments.find(params[:enrollment_id])
    end

    def transbank_return_url
      transbank_callback_url
    end
  end
end
