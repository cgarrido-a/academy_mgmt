module Admin
  class EnrollmentsController < Admin::ApplicationController
    before_action :set_enrollment, only: [:show, :edit, :update, :destroy]

    def index
      @enrollments = Enrollment.includes(student: :user, section: :course, payment_plan: [], payment_method: [])
                               .order(created_at: :desc)
    end

    def show
      @tuition_fee = @enrollment.tuition_fee
      @installments = @tuition_fee&.installments || []
    end

    def new
      @enrollment = Enrollment.new
      load_form_data
    end

    def create
      @enrollment = Enrollment.new(enrollment_params)

      if @enrollment.save
        redirect_to admin_enrollment_path(@enrollment), notice: 'Inscripción creada exitosamente.'
      else
        load_form_data
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_data
    end

    def update
      if @enrollment.update(enrollment_params)
        redirect_to admin_enrollment_path(@enrollment), notice: 'Inscripción actualizada exitosamente.'
      else
        load_form_data
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @enrollment.destroy
      redirect_to admin_enrollments_path, notice: 'Inscripción eliminada exitosamente.'
    end

    private

    def set_enrollment
      @enrollment = Enrollment.find(params[:id])
    end

    def load_form_data
      @students = Student.includes(:user).all
      @sections = Section.includes(:course, :teacher).all
      @payment_plans = PaymentPlan.all
      @payment_methods = PaymentMethod.all
    end

    def enrollment_params
      params.require(:enrollment).permit(:student_id, :section_id, :payment_plan_id, :payment_method_id, :amount, :payment_date)
    end
  end
end
