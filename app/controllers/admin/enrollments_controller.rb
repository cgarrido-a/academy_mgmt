module Admin
  class EnrollmentsController < Admin::ApplicationController
    before_action :set_enrollment, only: [:show, :destroy]

    def index
      @enrollments = Enrollment.includes(student: :user, section: :course, payment_plan: [], payment_method: [])
                               .order(created_at: :desc)
    end

    def show
      @tuition_fee = @enrollment.tuition_fee
      @installments = @tuition_fee&.installments || []
    end

    def destroy
      @enrollment.destroy
      redirect_to admin_enrollments_path, notice: 'Inscripción eliminada exitosamente.'
    end

    private

    def set_enrollment
      @enrollment = Enrollment.find(params[:id])
    end
  end
end
