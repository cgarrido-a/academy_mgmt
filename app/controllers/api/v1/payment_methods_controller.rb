module Api
  module V1
    class PaymentMethodsController < BaseController
      # GET /api/v1/payment_methods
      def index
        payment_methods = PaymentMethod.all

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
