module Api
  module V1
    class EnrollmentsController < BaseController
      # POST /api/v1/enrollments
      def create
        creator = EnrollmentCreator.new(enrollment_params)

        if creator.call
          render json: {
            success: true,
            message: 'Enrollment created successfully',
            data: enrollment_data(creator.enrollment)
          }, status: :created
        else
          render json: {
            success: false,
            errors: creator.errors
          }, status: :unprocessable_entity
        end
      end

      private

      def enrollment_params
        params.require(:enrollment).permit(
          :name,
          :email,
          :section_id,
          :payment_plan_id,
          :payment_method_id,
          :enrollment_amount
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
          section: {
            id: enrollment.section.id,
            course: enrollment.section.course.title,
            schedule: enrollment.section.schedule,
            start_date: enrollment.section.start_date,
            end_date: enrollment.section.end_date
          },
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
    end
  end
end
