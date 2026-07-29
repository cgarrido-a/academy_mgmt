module Api
  module V1
    class PaymentPeriodsController < BaseController
      # GET /api/v1/payment_periods?weekly_plan_id=1&saturday=true
      # Los "períodos" definen las duraciones (meses) disponibles. El precio/descuento
      # se calcula por cantidad TOTAL de clases (modelo ClassDiscount), no por el período.
      def index
        payment_periods = PaymentPeriod.all.order(months: :asc)
        weekly_plan = params[:weekly_plan_id].present? ? WeeklyPlan.find_by(id: params[:weekly_plan_id]) : nil
        saturday = ActiveModel::Type::Boolean.new.cast(params[:saturday]) || false

        render json: {
          success: true,
          data: payment_periods.map { |period| payment_period_data(period, weekly_plan, saturday) }
        }
      end

      private

      def payment_period_data(period, weekly_plan = nil, saturday = false)
        data = {
          id: period.id,
          months: period.months,
          description: period.description
        }

        if weekly_plan && weekly_plan.number_of_classes.present?
          total = weekly_plan.calculate_final_price(period, saturday: saturday)

          if weekly_plan.event_type.present?
            # Clase de prueba / evento: precio propio, sin descuento por cantidad de clases.
            data[:pricing] = {
              total_classes: weekly_plan.number_of_classes,
              discount_percentage: 0,
              subtotal: total,
              discount_amount: 0,
              total: total,
              per_class: total
            }
          else
            total_classes = weekly_plan.number_of_classes * period.months
            discount      = ClassDiscount.discount_for(total_classes)
            base_per_class = weekly_plan.course&.base_price_per_class(saturday: saturday)
            subtotal      = base_per_class ? (base_per_class * total_classes).round : total

            data[:pricing] = {
              total_classes: total_classes,
              discount_percentage: discount,
              subtotal: subtotal,
              discount_amount: subtotal - total,
              total: total,
              per_class: total_classes.positive? ? (total.to_f / total_classes).round : nil
            }
          end
        end

        data
      end
    end
  end
end
