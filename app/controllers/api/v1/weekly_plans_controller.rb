module Api
  module V1
    class WeeklyPlansController < BaseController
      # GET /api/v1/weekly_plans
      def index
        weekly_plans = WeeklyPlan.all

        render json: {
          success: true,
          data: weekly_plans.map { |plan| weekly_plan_data(plan) }
        }
      end

      private

      def weekly_plan_data(plan)
        {
          id: plan.id,
          plan: plan.plan,
          description: plan.description,
          price: plan.price,
          saturday_price: plan.saturday_price,
          enrollment_fee: plan.enrollment_fee,
          weekly_classes: plan.weekly_classes,
          number_of_classes: plan.number_of_classes,
          event_type: plan.event_type
        }
      end
    end
  end
end
