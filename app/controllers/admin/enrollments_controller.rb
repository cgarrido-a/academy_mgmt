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
      success = false

      ActiveRecord::Base.transaction do
        if @enrollment.save
          # Create tuition fee and installments if requested
          if params[:create_tuition_fee] == '1'
            create_tuition_fee_and_installments
          end
          success = true
        end
      end

      if success
        redirect_to admin_enrollment_path(@enrollment), notice: 'Inscripción creada exitosamente.'
      else
        load_form_data
        render :new, status: :unprocessable_entity
      end
    rescue StandardError => e
      @enrollment.errors.add(:base, "Error al crear la inscripción: #{e.message}")
      load_form_data
      render :new, status: :unprocessable_entity
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
      params.require(:enrollment).permit(:student_id, :section_id, :payment_plan_id, :payment_method_id, :enrollment_amount, :payment_date)
    end

    def create_tuition_fee_and_installments
      section = @enrollment.section

      # Generate or use provided billing period
      billing_period = params[:billing_period].presence || generate_billing_period(section)

      # Use provided total_tuition_fee or default to enrollment_amount
      total_fee = params[:total_tuition_fee].presence&.to_f || @enrollment.enrollment_amount

      # Use provided instalments_number
      instalments_number = params[:instalments_number].presence&.to_i || 1

      # Create tuition fee
      tuition_fee = TuitionFee.create!(
        enrollment: @enrollment,
        payment_method_id: @enrollment.payment_method_id,
        total_tuition_fee: total_fee,
        instalments_number: instalments_number,
        billing_period: billing_period
      )

      # Generate installments
      generate_installments(tuition_fee, instalments_number)
    end

    def generate_installments(tuition_fee, number_of_installments)
      amount_per_installment = (tuition_fee.total_tuition_fee.to_f / number_of_installments).round

      # Get first due date from params or default to next month
      first_due_date = params[:first_due_date].present? ? Date.parse(params[:first_due_date]) : Date.today + 1.month

      number_of_installments.times do |i|
        # Adjust last installment to account for rounding differences
        installment_amount = if i == number_of_installments - 1
          tuition_fee.total_tuition_fee - (amount_per_installment * (number_of_installments - 1))
        else
          amount_per_installment
        end

        Installment.create!(
          tuition_fee: tuition_fee,
          amount: installment_amount,
          due_date: first_due_date + i.months,
          status: 'pending'
        )
      end
    end

    def generate_billing_period(section)
      "#{section.start_date.strftime('%Y-%m')} - #{section.end_date.strftime('%Y-%m')}"
    end
  end
end
