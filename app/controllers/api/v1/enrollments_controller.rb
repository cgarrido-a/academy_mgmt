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
          :section_id,
          :payment_plan_id,
          :payment_method_id,
          :enrollment_amount,
          :total_tuition_fee,
          section_ids: []
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
          sections: enrollment.sections.map do |section|
            {
              id: section.id,
              course: section.course.title,
              schedule: section.schedule,
              start_date: section.start_date,
              end_date: section.end_date
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
          tuition_fee: tuition_fee_data(enrollment.tuition_fee)
        }
      end

      def tuition_fee_data(tuition_fee)
        return nil unless tuition_fee

        {
          id: tuition_fee.id,
          total_tuition_fee: tuition_fee.total_tuition_fee,
          instalments_number: tuition_fee.instalments_number,
          billing_period: tuition_fee.billing_period,
          installments: tuition_fee.installments.map { |installment| installment_data(installment) }
        }
      end

      def installment_data(installment)
        {
          id: installment.id,
          amount: installment.amount,
          due_date: installment.due_date,
          status: installment.status
        }
      end

      def initialize_transbank_payment(enrollment)
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
          enrollment.enrollment_amount.to_i,
          transbank_callback_url
        )

        # NOW create Transbank transaction record with the token
        TransbankTransaction.create!(
          enrollment: enrollment,
          payment_type: 'enrollment_fee',
          buy_order: buy_order,
          amount: enrollment.enrollment_amount,
          status: 'pending',
          token: response['token']
        )

        # Return Transbank payment data
        {
          url: response['url'],
          token: response['token'],
          full_url: "#{response['url']}?token_ws=#{response['token']}",
          buy_order: buy_order,
          amount: enrollment.enrollment_amount
        }
      end

      def transbank_callback_url
        # This should point to your backend callback URL
        # Adjust the host/domain as needed for your environment
        if Rails.env.production?
          "#{ENV['BACKEND_URL']}/transbank/callback"
        else
          "http://localhost:3001/transbank/callback"
        end
      end
    end
  end
end
