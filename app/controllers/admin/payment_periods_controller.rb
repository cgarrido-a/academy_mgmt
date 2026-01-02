module Admin
  class PaymentPeriodsController < Admin::ApplicationController
    before_action :set_payment_period, only: [:show, :edit, :update, :destroy]

    def index
      @payment_periods = PaymentPeriod.all.order(months: :asc)
    end

    def show
    end

    def new
      @payment_period = PaymentPeriod.new
    end

    def create
      @payment_period = PaymentPeriod.new(payment_period_params)

      if @payment_period.save
        redirect_to admin_payment_periods_path, notice: 'Descuento por período creado exitosamente.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @payment_period.update(payment_period_params)
        redirect_to admin_payment_periods_path, notice: 'Descuento por período actualizado exitosamente.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @payment_period.destroy
      redirect_to admin_payment_periods_path, notice: 'Descuento por período eliminado exitosamente.'
    end

    private

    def set_payment_period
      @payment_period = PaymentPeriod.find(params[:id])
    end

    def payment_period_params
      params.require(:payment_period).permit(:months, :discount_percentage, :description)
    end
  end
end
