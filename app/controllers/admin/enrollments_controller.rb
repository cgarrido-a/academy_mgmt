module Admin
  class EnrollmentsController < Admin::ApplicationController
    before_action :set_enrollment, only: [:show, :edit, :update, :destroy]

    def index
      @enrollments = Enrollment.includes(student: :user, sections: :course, weekly_plan: [], payment_method: [])
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
      params_for_enrollment = enrollment_params.except(:section_id, :section_ids, :start_date, :class_dates)
      section_ids = (enrollment_params[:section_ids] || []).reject(&:blank?)
      class_dates = (enrollment_params[:class_dates] || []).reject(&:blank?)
      @enrollment = Enrollment.new(params_for_enrollment)
      success = false

      # Validate at least one section is selected
      if section_ids.empty?
        @enrollment.errors.add(:base, "Debe seleccionar al menos una sección")
        load_form_data
        render :new, status: :unprocessable_entity
        return
      end

      # Validate class dates are provided
      if class_dates.empty?
        @enrollment.errors.add(:base, "Debe generar las fechas de clase")
        load_form_data
        render :new, status: :unprocessable_entity
        return
      end

      ActiveRecord::Base.transaction do
        if @enrollment.save
          # Create enrollment sections using the selected/edited dates
          section_ids.each do |section_id|
            # Create an enrollment_section for each class date
            class_dates.each do |date_str|
              date = Date.parse(date_str)
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
              payment_date: @enrollment.payment_date,
              payment_method_id: @enrollment.payment_method_id,
              status: 'completed'
            )
          end

          # Create tuition fee and installments (always)
          # create_tuition_fee_and_installments # Removed: tuition_fees table no longer exist
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
      params_for_enrollment = enrollment_params.except(:section_id, :section_ids, :start_date, :class_dates)
      section_ids = (enrollment_params[:section_ids] || []).reject(&:blank?)
      class_dates = (enrollment_params[:class_dates] || []).reject(&:blank?)

      # Validate at least one section is selected
      if section_ids.empty?
        @enrollment.errors.add(:base, "Debe seleccionar al menos una sección")
        load_form_data
        render :edit, status: :unprocessable_entity
        return
      end

      # Validate class dates are provided
      if class_dates.empty?
        @enrollment.errors.add(:base, "Debe generar las fechas de clase")
        load_form_data
        render :edit, status: :unprocessable_entity
        return
      end

      ActiveRecord::Base.transaction do
        if @enrollment.update(params_for_enrollment)
          # Update enrollment sections using the selected/edited dates
          @enrollment.enrollment_sections.destroy_all

          section_ids.each do |section_id|
            # Create an enrollment_section for each class date
            class_dates.each do |date_str|
              date = Date.parse(date_str)
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

    def sections_by_course
      course_id = params[:course_id]
      @sections = Section.includes(:course, teacher: :user).where(course_id: course_id)

      sections_data = @sections.map do |s|
        schedule_entry = s.schedule.is_a?(Array) && s.schedule.first ? s.schedule.first : {}
        {
          id: s.id,
          weekday: s.weekday,
          start_time: schedule_entry['start_time'],
          end_time: schedule_entry['end_time'],
          teacher: s.teacher.user.name,
          places: s.places,
          label: "#{s.weekday} #{s.formatted_schedule} - #{s.teacher.user.name} (#{s.places} cupos)"
        }
      end

      render json: { sections: sections_data }
    end

    private

    def set_enrollment
      @enrollment = Enrollment.includes(:sections, :enrollment_sections).find(params[:id])
    end

    def load_form_data
      @students = Student.includes(:user).all
      @courses = Course.all
      @sections = Section.includes(:course, teacher: :user).all
      @weekly_plans = WeeklyPlan.all
      @payment_methods = PaymentMethod.all

      # Check if there are any weekly plans
      if @weekly_plans.empty?
        flash.now[:alert] = "No existen planes semanales registrados. Por favor, cree al menos un plan antes de crear una inscripción."
      end
    end

    def enrollment_params
      permitted = params.require(:enrollment).permit(:student_id, :section_id, :weekly_plan_id, :payment_method_id, :enrollment_amount, :total_tuition_fee, :payment_date, :start_date, section_ids: [], class_dates: [])

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
