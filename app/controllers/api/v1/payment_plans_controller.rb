module Api
  module V1
    class PaymentPlansController < BaseController
      # GET /api/v1/payment_plans
      def index
        payment_plans = PaymentPlan.all

        render json: {
          success: true,
          data: payment_plans.map { |plan| payment_plan_data(plan) }
        }
      end

      private

      def payment_plan_data(plan)
        {
          id: plan.id,
          plan: plan.plan,
          description: plan.description,
          weekly_classes: plan.weekly_classes
        }
      end
    end
  end
end
