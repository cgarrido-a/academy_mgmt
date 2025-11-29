module Admin
  class EnrollmentsController < Admin::ApplicationController
    before_action :set_enrollment, only: [:show, :edit, :update, :destroy]

    def index
      @enrollments = Enrollment.includes(student: :user, sections: :course, payment_plan: [], payment_method: [])
                               .order(created_at: :desc)
    end

    def show
      # @tuition_fee = @enrollment.tuition_fee # Removed: tuition_fees table no longer exists
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
          # Create enrollment sections for all classes in the payment plan
          # Use provided section_date as start date, or default to today
          start_date = enrollment_params[:date].presence || Date.today
          start_date = Date.parse(start_date) if start_date.is_a?(String)

          # Get number of classes from payment plan
          number_of_classes = @enrollment.payment_plan.number_of_classes

          section_ids.each do |section_id|
            section = Section.find(section_id)

            # Generate dates for all classes
            class_dates = generate_class_dates(section, start_date, number_of_classes)

            # Create an enrollment_section for each class date
            class_dates.each do |date|
              EnrollmentSection.create!(
                enrollment: @enrollment,
                section_id: section_id,
                date: date
              )
            end
          end

          # Register enrollment fee payment if payment_date is provided
          if @enrollment.payment_date.present?
            Payment.create!(
              enrollment: @enrollment,
              payment_type: 'enrollment_fee',
              amount: @enrollment.enrollment_amount,
              total_tuition_fee: @enrollment.total_tuition_fee,
              payment_date: @enrollment.payment_date,
              payment_method_id: @enrollment.payment_method_id,
              status: 'completed'
            )
          end

          # Create tuition fee and installments (always)
          # create_tuition_fee_and_installments # Removed: tuition_fees table no longer exists
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
          # Use provided section_date as start date, or default to today
          start_date = enrollment_params[:section_date].presence || Date.today
          start_date = Date.parse(start_date) if start_date.is_a?(String)

          # Get number of classes from payment plan
          number_of_classes = @enrollment.payment_plan.number_of_classes

          @enrollment.enrollment_sections.destroy_all
          section_ids.each do |section_id|
            section = Section.find(section_id)

            # Generate dates for all classes
            class_dates = generate_class_dates(section, start_date, number_of_classes)

            # Create an enrollment_section for each class date
            class_dates.each do |date|
              EnrollmentSection.create!(
                enrollment: @enrollment,
                section_id: section_id,
                date: date
              )
            end
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
      permitted = params.require(:enrollment).permit(:student_id, :section_id, :payment_plan_id, :payment_method_id, :enrollment_amount, :total_tuition_fee, :payment_date, :date, section_ids: [])

      # Convert section_id to section_ids array for compatibility
      if permitted[:section_id].present? && permitted[:section_ids].blank?
        permitted[:section_ids] = [permitted[:section_id]]
      end

      permitted
    end

    # Removed: tuition_fees and installments tables no longer exist
    # def create_tuition_fee_and_installments
    #   ...
    # end

    # def generate_installments(tuition_fee, number_of_installments)
    #   ...
    # end

    # def generate_billing_period(section)
    #   ...
    # end

    def generate_class_dates(section, start_date, number_of_classes)
      # Map Spanish weekday names to Ruby's wday (0 = Sunday, 1 = Monday, etc.)
      weekday_map = {
        'Domingo' => 0,
        'Lunes' => 1,
        'Martes' => 2,
        'Miércoles' => 3,
        'Jueves' => 4,
        'Viernes' => 5,
        'Sábado' => 6
      }

      target_wday = weekday_map[section.weekday]
      dates = []
      current_date = start_date

      # Ensure start_date matches the section's weekday
      unless current_date.wday == target_wday
        raise "La fecha de inicio #{start_date.strftime('%d/%m/%Y')} no es un #{section.weekday}"
      end

      # Generate the specified number of class dates with available spots
      max_attempts = number_of_classes * 10  # Evitar bucle infinito
      attempts = 0

      while dates.length < number_of_classes && attempts < max_attempts
        # Check if this date has available places
        if section.has_available_places_for_date?(current_date)
          dates << current_date
        end
        # If no spots available, skip to next week

        current_date += 7.days  # Next week, same day
        attempts += 1
      end

      if dates.length < number_of_classes
        raise "No se pudieron encontrar #{number_of_classes} fechas con cupos disponibles. Solo se encontraron #{dates.length} fechas."
      end

      dates
    end
  end
end
