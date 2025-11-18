module Admin
  class PaymentsController < Admin::ApplicationController
    before_action :set_payment, only: [:show, :edit, :update, :destroy]

    def index
      @payments = Payment.includes(:enrollment, :payment_method, enrollment: { student: :user })
                        .order(payment_date: :desc)
                        .page(params[:page]).per(50)
    end

    def show
    end

    def new
      @payment = Payment.new
      @enrollment = Enrollment.find(params[:enrollment_id]) if params[:enrollment_id]
      load_form_data
    end

    def create
      @payment = Payment.new(payment_params)

      if @payment.save
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
      @payment = Payment.includes(:enrollment, :payment_method, enrollment: { student: :user }).find(params[:id])
    end

    def load_form_data
      @enrollments = Enrollment.includes(student: :user).order('users.name')
      @payment_methods = PaymentMethod.all
    end

    def payment_params
      params.require(:payment).permit(
        :enrollment_id,
        :payment_type,
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
