module Student
  class PaymentsController < ApplicationController
    before_action :set_student
    before_action :set_enrollment, only: [:pay_enrollment_fee, :pay_installment]
    before_action :set_installment, only: [:pay_installment]

    # GET /student/payments
    def index
      @enrollments = @student.enrollments.includes(:sections, :payment_plan, :payment_method, :tuition_fee)
      @pending_enrollment_fees = @enrollments.reject(&:enrollment_fee_paid?)

      # Get all pending installments
      @pending_installments = Installment.joins(tuition_fee: :enrollment)
                                        .where(enrollments: { student_id: @student.id })
                                        .where.not(status: 'paid')
                                        .includes(tuition_fee: { enrollment: [:student, :sections] })
                                        .order(:due_date)
    end

    # POST /student/payments/pay_enrollment_fee/:enrollment_id
    def pay_enrollment_fee
      if @enrollment.enrollment_fee_paid?
        redirect_to student_payments_path, alert: 'La matrícula ya ha sido pagada.'
        return
      end

      # Generate buy order
      buy_order = TransbankTransaction.generate_buy_order(@enrollment.id, 'enrollment_fee')

      # Create Transbank transaction record
      transaction_record = TransbankTransaction.create!(
        enrollment: @enrollment,
        payment_type: 'enrollment_fee',
        buy_order: buy_order,
        amount: @enrollment.enrollment_amount,
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
        amount: @enrollment.enrollment_amount.to_i,
        return_url: transbank_return_url
      )

      # Update transaction with token
      transaction_record.update!(token: response['token'])

      # Redirect to Transbank
      redirect_to "#{response['url']}?token_ws=#{response['token']}", allow_other_host: true

    rescue StandardError => e
      Rails.logger.error "Error creating Transbank transaction: #{e.message}"
      redirect_to student_payments_path, alert: "Error al procesar el pago: #{e.message}"
    end

    # POST /student/payments/pay_installment/:enrollment_id/:installment_id
    def pay_installment
      if @installment.fully_paid?
        redirect_to student_payments_path, alert: 'Esta cuota ya ha sido pagada.'
        return
      end

      amount_to_pay = @installment.remaining_amount

      # Generate buy order
      buy_order = TransbankTransaction.generate_buy_order(@enrollment.id, 'installment', @installment.id)

      # Create Transbank transaction record
      transaction_record = TransbankTransaction.create!(
        enrollment: @enrollment,
        installment: @installment,
        payment_type: 'installment',
        buy_order: buy_order,
        amount: amount_to_pay,
        status: 'pending',
        token: ''
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
        amount: amount_to_pay.to_i,
        return_url: transbank_return_url
      )

      # Update transaction with token
      transaction_record.update!(token: response['token'])

      # Redirect to Transbank
      redirect_to "#{response['url']}?token_ws=#{response['token']}", allow_other_host: true

    rescue StandardError => e
      Rails.logger.error "Error creating Transbank transaction: #{e.message}"
      redirect_to student_payments_path, alert: "Error al procesar el pago: #{e.message}"
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

    def set_installment
      @installment = Installment.joins(tuition_fee: :enrollment)
                                .where(enrollments: { id: @enrollment.id })
                                .find(params[:installment_id])
    end

    def transbank_return_url
      transbank_callback_url
    end
  end
end
