module Admin
  class PaymentPlansController < Admin::ApplicationController
    before_action :set_payment_plan, only: [:show, :edit, :update, :destroy]

    def index
      @payment_plans = PaymentPlan.all.order(plan: :asc)
    end

    def show
      @enrollments = @payment_plan.enrollments.includes(student: :user, sections: :course)
    end

    def new
      @payment_plan = PaymentPlan.new
    end

    def create
      @payment_plan = PaymentPlan.new(payment_plan_params)

      if @payment_plan.save
        redirect_to admin_payment_plans_path, notice: 'Plan de pago creado exitosamente.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @payment_plan.update(payment_plan_params)
        redirect_to admin_payment_plans_path, notice: 'Plan de pago actualizado exitosamente.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @payment_plan.enrollments.exists?
        redirect_to admin_payment_plans_path, alert: 'No se puede eliminar un plan de pago con inscripciones asociadas.'
      else
        @payment_plan.destroy
        redirect_to admin_payment_plans_path, notice: 'Plan de pago eliminado exitosamente.'
      end
    end

    private

    def set_payment_plan
      @payment_plan = PaymentPlan.find(params[:id])
    end

    def payment_plan_params
      params.require(:payment_plan).permit(:plan, :description, :price, :weekly_classes)
    end
  end
end
