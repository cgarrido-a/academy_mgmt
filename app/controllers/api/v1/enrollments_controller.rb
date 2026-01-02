module Api
  module V1
    class EnrollmentsController < BaseController
      # POST /api/v1/enrollments
      def create
        # Initialize Transbank payment WITHOUT creating enrollment
        # Enrollment will be created after successful payment
        transbank_data = initialize_transbank_payment_with_data(enrollment_params)

        render json: {
          success: true,
          message: 'Transacción iniciada. Complete el pago para finalizar la inscripción',
          transbank_payment: transbank_data
        }, status: :created
      rescue StandardError => e
        Rails.logger.error "Error creating enrollment with Transbank: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        render json: {
          success: false,
          error: "Error al procesar la inscripción: #{e.message}"
        }, status: :internal_server_error
      end

      private

      def enrollment_params
        params.require(:enrollment).permit(
          :name,
          :email,
          :phone,
          :start_date,
          :section_id,
          :weekly_plan_id,
          :payment_method_id,
          :enrollment_amount,
          :total_tuition_fee,
          section_ids: [],
          section_dates: {}
        )
      end

      def initialize_transbank_payment_with_data(params)
        puts "Initializing Transbank payment with enrollment data: #{params.inspect}"

        # Generate a short buy order for pending enrollment (max 26 chars)
        # Format: PEND-{timestamp} (e.g., "PEND-1733452718" = 15 chars)
        buy_order = "PEND-#{Time.now.to_i}"

        # Log Transbank configuration for debugging
        Rails.logger.info "Transbank Config - Environment: #{TransbankConfig.environment}"
        Rails.logger.info "Transbank Config - Commerce Code present: #{TransbankConfig.commerce_code.present?}"
        Rails.logger.info "Transbank Config - API Key present: #{TransbankConfig.api_key.present?}"
        Rails.logger.info "Transbank Config - Commerce Code length: #{TransbankConfig.commerce_code&.length}"
        Rails.logger.info "Transbank Config - API Key length: #{TransbankConfig.api_key&.length}"

        # Initialize Webpay Plus transaction FIRST to get the token
        # Create an options object using OpenStruct (same as TransbankController)
        require 'ostruct'

        options = OpenStruct.new(
          commerce_code: ::TransbankConfig.commerce_code,
          api_key: ::TransbankConfig.api_key,
          environment: ::TransbankConfig.environment,
          timeout: 15000
        )

        tx = Transbank::Webpay::WebpayPlus::Transaction.new(options)

        response = tx.create(
          buy_order,
          SecureRandom.hex(10),
          params[:total_tuition_fee].to_i,
          transbank_callback_url
        )

        # Create Transbank transaction record WITHOUT enrollment, storing enrollment_data instead
        transaction_record = TransbankTransaction.create!(
          enrollment_id: nil,
          enrollment_data: params.to_h,
          payment_type: 'enrollment_fee',
          buy_order: buy_order,
          amount: params[:total_tuition_fee],
          status: 'pending',
          token: response['token']
        )

        # Return Transbank payment data
        {
          url: response['url'],
          token: response['token'],
          full_url: "#{response['url']}?token_ws=#{response['token']}",
          buy_order: buy_order,
          amount: params[:total_tuition_fee],
          transaction_id: transaction_record.id
        }
      end

      def transbank_callback_url
        # This should point to your backend callback URL
        # Adjust the host/domain as needed for your environment
        backend_url = ENV['BACKEND_URL'] || 'https://decided-east-calling-threatening.trycloudflare.com'
        "#{backend_url}/transbank/callback"
      end
    end
  end
end
