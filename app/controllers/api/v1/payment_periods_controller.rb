module Api
  module V1
    class PaymentPeriodsController < BaseController
      # GET /api/v1/payment_periods?weekly_plan_id=1
      def index
        payment_periods = PaymentPeriod.all.order(months: :asc)
        weekly_plan = params[:weekly_plan_id].present? ? WeeklyPlan.find_by(id: params[:weekly_plan_id]) : nil

        render json: {
          success: true,
          data: payment_periods.map { |period| payment_period_data(period, weekly_plan) }
        }
      end

      private

      def payment_period_data(period, weekly_plan = nil)
        data = {
          id: period.id,
          months: period.months,
          discount_percentage: period.discount_percentage,
          description: period.description
        }

        # Si se proporciona un plan, calcular el precio total
        if weekly_plan && weekly_plan.price.present?
          monthly_price = weekly_plan.price
          subtotal = monthly_price * period.months
          discount_amount = subtotal * (period.discount_percentage / 100.0)
          total = subtotal - discount_amount

          data[:pricing] = {
            monthly_price: monthly_price,
            subtotal: subtotal,
            discount_amount: discount_amount,
            total: total.round
          }
        end

        data
      end
    end
  end
end
