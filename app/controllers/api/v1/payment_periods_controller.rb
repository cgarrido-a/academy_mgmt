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

        # Si se proporciona un plan, calcular el precio total con el modelo aditivo
        # (frecuencia + período), delegando en WeeklyPlan#calculate_final_price para
        # tener una sola fuente de verdad con el cobro real.
        if weekly_plan && weekly_plan.price.present?
          freq_discount = (weekly_plan.discount_percentage || 0).to_f
          undiscounted_monthly = freq_discount < 100 ? weekly_plan.price / (1 - freq_discount / 100.0) : weekly_plan.price
          subtotal = (undiscounted_monthly * period.months).round
          total = weekly_plan.calculate_final_price(period)

          data[:pricing] = {
            monthly_price: weekly_plan.price,
            subtotal: subtotal,
            discount_amount: subtotal - total,
            freq_discount_percentage: freq_discount,
            total: total
          }
        end

        data
      end
    end
  end
end
