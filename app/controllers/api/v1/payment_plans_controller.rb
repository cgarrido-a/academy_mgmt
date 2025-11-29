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
          price: plan.price,
          description: plan.description,
          number_of_classes: plan.number_of_classes
        }
      end
    end
  end
end
