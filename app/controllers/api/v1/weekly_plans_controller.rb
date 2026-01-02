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
          weekly_classes: plan.weekly_classes
        }
      end
    end
  end
end
