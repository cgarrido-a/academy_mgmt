module Api
  module V1
    class EnrollmentsController < BaseController
      # POST /api/v1/enrollments
      def create
        # Initialize Transbank payment WITHOUT creating enrollments
        # Enrollments will be created after successful payment
        transbank_data = initialize_transbank_payment_with_data(enrollments_params)

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

      def enrollments_params
        # Accept an array of enrollments
        params.require(:enrollments).map do |enrollment|
          enrollment.permit(
            :name,
            :email,
            :phone,
            :start_date,
            :section_id,
            :weekly_plan_id,
            :payment_method_id,
            :payment_period_id,
            section_ids: [],
            section_dates: {}
          )
        end
      end

      def initialize_transbank_payment_with_data(enrollments_array)
        puts "Initializing Transbank payment with enrollments data: #{enrollments_array.inspect}"

        # Calculate total amount by summing all enrollments
        total_amount = 0

        enrollments_array.each do |enrollment_params|
          weekly_plan = WeeklyPlan.find(enrollment_params[:weekly_plan_id])
          section_ids = enrollment_params[:section_ids] || [enrollment_params[:section_id]].compact

          if enrollment_params[:payment_period_id].present?
            payment_period = PaymentPeriod.find(enrollment_params[:payment_period_id])
            enrollment_total = weekly_plan.calculate_final_price(payment_period, section_ids: section_ids)
          else
            # Use base price (Saturday price if sections are on Saturday)
            enrollment_total = weekly_plan.determine_base_price(section_ids)
          end

          total_amount += enrollment_total
        end

        # Generate a short buy order for pending enrollments (max 26 chars)
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
          total_amount.to_i,
          transbank_callback_url
        )

        # Create Transbank transaction record WITHOUT enrollment, storing enrollments_array as enrollment_data
        transaction_record = TransbankTransaction.create!(
          enrollment_id: nil,
          enrollment_data: { enrollments: enrollments_array.map(&:to_h) },
          payment_type: 'enrollment_fee',
          buy_order: buy_order,
          amount: total_amount,
          status: 'pending',
          token: response['token']
        )

        # Log token for Transbank integration testing
        Rails.logger.info "=" * 80
        Rails.logger.info "TRANSBANK TOKEN GENERADO (API):"
        Rails.logger.info "Token: #{response['token']}"
        Rails.logger.info "Buy Order: #{buy_order}"
        Rails.logger.info "Amount: #{total_amount}"
        Rails.logger.info "=" * 80

        # Return Transbank payment data
        {
          url: response['url'],
          token: response['token'],
          full_url: "#{response['url']}?token_ws=#{response['token']}",
          buy_order: buy_order,
          amount: total_amount,
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
