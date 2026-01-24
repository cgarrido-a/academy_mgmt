module Api
  module V1
    class PaymentMethodsController < BaseController
      # GET /api/v1/payment_methods
      # Solo retorna Webpay para pagos online del estudiante
      def index
        payment_methods = PaymentMethod.where('LOWER(payment_method) = ?', 'webpay')

        render json: {
          success: true,
          data: payment_methods.map { |method| payment_method_data(method) }
        }
      end

      private

      def payment_method_data(method)
        {
          id: method.id,
          payment_method: method.payment_method
        }
      end
    end
  end
end
