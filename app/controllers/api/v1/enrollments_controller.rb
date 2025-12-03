module Api
  module V1
    class EnrollmentsController < BaseController
      # POST /api/v1/enrollments
      def create
        creator = EnrollmentCreator.new(enrollment_params)

        if creator.call
          enrollment = creator.enrollment

          # Initialize Transbank payment for enrollment fee
          transbank_data = initialize_transbank_payment(enrollment)

          render json: {
            success: true,
            message: 'Enrollment created successfully',
            enrollment_id: enrollment.id,
            data: enrollment_data(enrollment),
            transbank_payment: transbank_data
          }, status: :created
        else
          render json: {
            success: false,
            errors: creator.errors
          }, status: :unprocessable_entity
        end
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
          :payment_plan_id,
          :payment_method_id,
          :enrollment_amount,
          :total_tuition_fee,
          section_ids: [],
          section_dates: {}
        )
      end

      def enrollment_data(enrollment)
        {
          id: enrollment.id,
          student: {
            id: enrollment.student.id,
            name: enrollment.student.user.name,
            email: enrollment.student.user.email
          },
          sections: enrollment.enrollment_sections.map do |enrollment_section|
            {
              id: enrollment_section.section.id,
              course: enrollment_section.section.course.title,
              weekday: enrollment_section.section.weekday,
              schedule: enrollment_section.section.schedule,
              date: enrollment_section.date
            }
          end,
          payment_plan: {
            id: enrollment.payment_plan.id,
            plan: enrollment.payment_plan.plan,
            description: enrollment.payment_plan.description
          },
          payment_method: {
            id: enrollment.payment_method.id,
            method: enrollment.payment_method.payment_method
          },
          enrollment_amount: enrollment.enrollment_amount,
          payment_date: enrollment.payment_date,
          total_tuition_fee: enrollment.total_tuition_fee
        }
      end


      def initialize_transbank_payment(enrollment)
        puts "Initializing Transbank payment for Enrollment ID: #{enrollment.inspect}"
        # Generate buy order
        buy_order = TransbankTransaction.generate_buy_order(enrollment.id, 'enrollment_fee')

        # Initialize Webpay Plus transaction FIRST to get the token
        # Create an options object
        options = Struct.new(:commerce_code, :api_key, :environment, :timeout).new(
          ::TransbankConfig.commerce_code,
          ::TransbankConfig.api_key,
          ::TransbankConfig.environment,
          15000 # timeout in milliseconds
        )

        tx = Transbank::Webpay::WebpayPlus::Transaction.new(options)

        response = tx.create(
          buy_order,
          SecureRandom.hex(10),
          enrollment.total_tuition_fee.to_i,
          transbank_callback_url
        )

        # NOW create Transbank transaction record with the token
        TransbankTransaction.create!(
          enrollment: enrollment,
          payment_type: 'enrollment_fee',
          buy_order: buy_order,
          amount: enrollment.total_tuition_fee,
          status: 'pending',
          token: response['token']
        )

        # Return Transbank payment data
        {
          url: response['url'],
          token: response['token'],
          full_url: "#{response['url']}?token_ws=#{response['token']}",
          buy_order: buy_order,
          amount: enrollment.total_tuition_fee
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
