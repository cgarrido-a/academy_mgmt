module Admin
  class PaymentsController < Admin::ApplicationController
    before_action :set_payment, only: [:show, :edit, :update, :destroy]

    def index
      @payments = Payment.includes(:enrollment, :installment, :payment_method, enrollment: { student: :user })
                        .order(payment_date: :desc)
                        .page(params[:page]).per(50)
    end

    def show
    end

    def new
      @payment = Payment.new
      @enrollment = Enrollment.find(params[:enrollment_id]) if params[:enrollment_id]
      @installment = Installment.find(params[:installment_id]) if params[:installment_id]
      load_form_data
    end

    def create
      @payment = Payment.new(payment_params)

      if @payment.save
        # Update installment status if it's an installment payment
        @payment.installment&.update_payment_status!

        redirect_to admin_payment_path(@payment), notice: 'Pago registrado exitosamente.'
      else
        load_form_data
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_data
    end

    def update
      if @payment.update(payment_params)
        # Update installment status if it's an installment payment
        @payment.installment&.update_payment_status!

        redirect_to admin_payment_path(@payment), notice: 'Pago actualizado exitosamente.'
      else
        load_form_data
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @payment.destroy
      redirect_to admin_payments_path, notice: 'Pago eliminado exitosamente.'
    end

    private

    def set_payment
      @payment = Payment.includes(:enrollment, :installment, :payment_method, enrollment: { student: :user }).find(params[:id])
    end

    def load_form_data
      @enrollments = Enrollment.includes(student: :user).order('users.name')
      @installments = Installment.includes(tuition_fee: { enrollment: { student: :user } }).order(due_date: :desc)
      @payment_methods = PaymentMethod.all
    end

    def payment_params
      params.require(:payment).permit(
        :enrollment_id,
        :payment_type,
        :installment_id,
        :amount,
        :payment_date,
        :payment_method_id,
        :reference_number,
        :notes,
        :status
      )
    end
  end
end
