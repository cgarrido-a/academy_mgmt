module Api
  module V1
    class PaymentPeriodsController < BaseController
      # GET /api/v1/payment_periods
      def index
        payment_periods = PaymentPeriod.all.order(months: :asc)

        render json: {
          success: true,
          data: payment_periods.map { |period| payment_period_data(period) }
        }
      end

      private

      def payment_period_data(period)
        {
          id: period.id,
          months: period.months,
          discount_percentage: period.discount_percentage,
          description: period.description
        }
      end
    end
  end
end
