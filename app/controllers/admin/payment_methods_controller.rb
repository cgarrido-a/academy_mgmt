module Admin
  class PaymentMethodsController < Admin::ApplicationController
    load_and_authorize_resource
    before_action :set_payment_method, only: [:show, :edit, :update, :destroy]

    def index
      @payment_methods = PaymentMethod.all.order(payment_method: :asc)
    end

    def show
      @enrollments = @payment_method.enrollments.includes(student: :user, sections: :course).limit(10)
    end

    def new
      @payment_method = PaymentMethod.new
    end

    def create
      @payment_method = PaymentMethod.new(payment_method_params)

      if @payment_method.save
        redirect_to admin_payment_methods_path, notice: 'Método de pago creado exitosamente.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @payment_method.update(payment_method_params)
        redirect_to admin_payment_methods_path, notice: 'Método de pago actualizado exitosamente.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @payment_method.enrollments.exists? || @payment_method.teacher_payments.exists?
        redirect_to admin_payment_methods_path, alert: 'No se puede eliminar un método de pago con registros asociados.'
      else
        @payment_method.destroy
        redirect_to admin_payment_methods_path, notice: 'Método de pago eliminado exitosamente.'
      end
    end

    private

    def set_payment_method
      @payment_method = PaymentMethod.find(params[:id])
    end

    def payment_method_params
      params.require(:payment_method).permit(:payment_method)
    end
  end
end
