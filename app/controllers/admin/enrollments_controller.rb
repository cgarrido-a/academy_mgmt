module Admin
  class EnrollmentsController < Admin::ApplicationController
    before_action :set_enrollment, only: [:show, :edit, :update, :destroy]

    def index
      @enrollments = Enrollment.includes(student: :user, sections: :course, payment_plan: [], payment_method: [])
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
      params_for_enrollment = enrollment_params.except(:section_id, :section_ids)
      section_ids = (enrollment_params[:section_ids] || []).reject(&:blank?)
      @enrollment = Enrollment.new(params_for_enrollment)
      success = false

      # Validate at least one section is selected
      if section_ids.empty?
        @enrollment.errors.add(:base, "Debe seleccionar al menos una sección")
        load_form_data
        render :new, status: :unprocessable_entity
        return
      end

      ActiveRecord::Base.transaction do
        if @enrollment.save
          # Create enrollment sections
          section_ids.each do |section_id|
            EnrollmentSection.create!(
              enrollment: @enrollment,
              section_id: section_id
            )
          end

          # Register enrollment fee payment if payment_date is provided
          if @enrollment.payment_date.present?
            Payment.create!(
              enrollment: @enrollment,
              payment_type: 'enrollment_fee',
              amount: @enrollment.enrollment_amount,
              payment_date: @enrollment.payment_date,
              payment_method_id: @enrollment.payment_method_id,
              status: 'completed'
            )
          end

          # Create tuition fee and installments (always)
          create_tuition_fee_and_installments
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
      params_for_enrollment = enrollment_params.except(:section_id, :section_ids)
      section_ids = (enrollment_params[:section_ids] || []).reject(&:blank?)

      # Validate at least one section is selected
      if section_ids.empty?
        @enrollment.errors.add(:base, "Debe seleccionar al menos una sección")
        load_form_data
        render :edit, status: :unprocessable_entity
        return
      end

      ActiveRecord::Base.transaction do
        if @enrollment.update(params_for_enrollment)
          # Update enrollment sections
          @enrollment.enrollment_sections.destroy_all
          section_ids.each do |section_id|
            EnrollmentSection.create!(
              enrollment: @enrollment,
              section_id: section_id
            )
          end
          redirect_to admin_enrollment_path(@enrollment), notice: 'Inscripción actualizada exitosamente.'
        else
          load_form_data
          render :edit, status: :unprocessable_entity
        end
      end
    rescue StandardError => e
      @enrollment.errors.add(:base, "Error al actualizar la inscripción: #{e.message}")
      load_form_data
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @enrollment.destroy
      redirect_to admin_enrollments_path, notice: 'Inscripción eliminada exitosamente.'
    end

    private

    def set_enrollment
      @enrollment = Enrollment.includes(:sections, :enrollment_sections).find(params[:id])
    end

    def load_form_data
      @students = Student.includes(:user).all
      @sections = Section.includes(:course, teacher: :user).all
      @payment_plans = PaymentPlan.all
      @payment_methods = PaymentMethod.all
    end

    def enrollment_params
      permitted = params.require(:enrollment).permit(:student_id, :section_id, :payment_plan_id, :payment_method_id, :enrollment_amount, :payment_date, section_ids: [])

      # Convert section_id to section_ids array for compatibility
      if permitted[:section_id].present? && permitted[:section_ids].blank?
        permitted[:section_ids] = [permitted[:section_id]]
      end

      permitted
    end

    def create_tuition_fee_and_installments
      section = @enrollment.sections.first

      return unless section # Skip if no sections

      # Generate or use provided billing period
      billing_period = params[:billing_period].presence || generate_billing_period(section)

      # Use provided total_tuition_fee (required field)
      total_fee = params[:total_tuition_fee].presence&.to_f

      # Validate total_tuition_fee is provided
      unless total_fee && total_fee > 0
        raise "Debe proporcionar un monto de arancel válido"
      end

      # Use provided instalments_number (defaults to 1)
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
