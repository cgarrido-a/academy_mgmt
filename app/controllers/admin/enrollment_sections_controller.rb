module Admin
  class EnrollmentSectionsController < Admin::ApplicationController
    load_and_authorize_resource
    before_action :set_enrollment_section, only: [:edit, :update, :destroy, :makeup, :assign_makeup]

    def edit
      @enrollment = @enrollment_section.enrollment
      @section = @enrollment_section.section
      @sections = Section.includes(:course, teacher: :user).all
    end

    # GET /admin/enrollment_sections/:id/makeup
    def makeup
      @enrollment = @enrollment_section.enrollment
      @origin_section = @enrollment_section.section

      unless @enrollment_section.regular? && @enrollment_section.attended == false && @enrollment_section.makeup.blank?
        redirect_to admin_enrollment_path(@enrollment),
                    alert: 'Sólo se puede asignar recuperatorio a una falta que aún no tenga uno.'
        return
      end

      load_makeup_options
      @makeup = EnrollmentSection.new(
        enrollment: @enrollment,
        kind: 'makeup',
        makes_up_for: @enrollment_section
      )
    end

    # POST /admin/enrollment_sections/:id/assign_makeup
    def assign_makeup
      @enrollment = @enrollment_section.enrollment
      @origin_section = @enrollment_section.section
      load_makeup_options

      unless @enrollment_section.regular? && @enrollment_section.attended == false && @enrollment_section.makeup.blank?
        redirect_to admin_enrollment_path(@enrollment),
                    alert: 'Esta falta ya tiene un recuperatorio o no es elegible.'
        return
      end

      section_id = makeup_params[:section_id]
      target_section = Section.find_by(id: section_id)

      if target_section.nil?
        flash.now[:alert] = 'Sección inválida.'
        @makeup = EnrollmentSection.new(makeup_params.merge(enrollment: @enrollment, kind: 'makeup', makes_up_for: @enrollment_section))
        render :makeup, status: :unprocessable_entity
        return
      end

      # Validar que la sección destino sea del mismo curso que la original
      if target_section.course_id != @origin_section.course_id
        flash.now[:alert] = 'El recuperatorio debe ser en una sección del mismo curso.'
        @makeup = EnrollmentSection.new(makeup_params.merge(enrollment: @enrollment, kind: 'makeup', makes_up_for: @enrollment_section))
        render :makeup, status: :unprocessable_entity
        return
      end

      # Si es profe, sólo puede asignar a sus propias secciones
      if current_teacher? && target_section.teacher_id != current_user.teacher.id
        flash.now[:alert] = 'Sólo el admin puede asignar recuperatorios en secciones de otros profesores. Coordina con el alumno e informa al admin.'
        @makeup = EnrollmentSection.new(makeup_params.merge(enrollment: @enrollment, kind: 'makeup', makes_up_for: @enrollment_section))
        render :makeup, status: :unprocessable_entity
        return
      end

      new_date = Date.parse(makeup_params[:date]) rescue nil
      if new_date.nil?
        flash.now[:alert] = 'Fecha inválida.'
        @makeup = EnrollmentSection.new(makeup_params.merge(enrollment: @enrollment, kind: 'makeup', makes_up_for: @enrollment_section))
        render :makeup, status: :unprocessable_entity
        return
      end

      weekday_map = Section::WEEKDAY_TO_WDAY
      target_wday = weekday_map[target_section.weekday]
      if new_date.wday != target_wday
        flash.now[:alert] = "La fecha debe ser un #{target_section.weekday}."
        @makeup = EnrollmentSection.new(makeup_params.merge(enrollment: @enrollment, kind: 'makeup', makes_up_for: @enrollment_section))
        render :makeup, status: :unprocessable_entity
        return
      end

      if new_date < Date.current
        flash.now[:alert] = 'La fecha del recuperatorio no puede estar en el pasado.'
        @makeup = EnrollmentSection.new(makeup_params.merge(enrollment: @enrollment, kind: 'makeup', makes_up_for: @enrollment_section))
        render :makeup, status: :unprocessable_entity
        return
      end

      @makeup = EnrollmentSection.new(
        enrollment: @enrollment,
        section: target_section,
        date: new_date,
        kind: 'makeup',
        makes_up_for: @enrollment_section,
        makeup_reason: makeup_params[:makeup_reason]
      )
      # Admin puede asignar recuperatorios fuera del período del plan (excepciones).
      @makeup.skip_period_rule = true if current_admin?

      if @makeup.save
        redirect_to admin_section_path(target_section, date: new_date),
                    notice: 'Recuperatorio asignado correctamente.'
      else
        flash.now[:alert] = @makeup.errors.full_messages.join(', ')
        render :makeup, status: :unprocessable_entity
      end
    end

    def update
      @enrollment = @enrollment_section.enrollment
      @sections = Section.includes(:course, teacher: :user).all

      # No permitir editar fecha/sección si ya hay asistencia marcada.
      # Para corregir asistencia confirmada se debe usar el flujo de recuperatorio.
      unless @enrollment_section.attended.nil?
        redirect_to admin_enrollment_path(@enrollment),
                    alert: 'No se puede editar una clase con asistencia ya marcada. Si necesitas reubicar al alumno usa "Asignar recuperatorio".'
        return
      end

      # Obtener la sección (puede ser la nueva o la actual)
      new_section_id = enrollment_section_params[:section_id] || @enrollment_section.section_id
      @section = Section.find(new_section_id)

      new_date = Date.parse(enrollment_section_params[:date])

      # Validar día de la semana con la nueva sección
      weekday_map = {
        'Domingo' => 0,
        'Lunes' => 1,
        'Martes' => 2,
        'Miércoles' => 3,
        'Jueves' => 4,
        'Viernes' => 5,
        'Sábado' => 6
      }
      target_wday = weekday_map[@section.weekday]

      unless new_date.wday == target_wday
        @enrollment_section.errors.add(:date, "debe ser un #{@section.weekday}")
        render :edit, status: :unprocessable_entity
        return
      end

      # Validar fecha futura
      if new_date < Date.today
        @enrollment_section.errors.add(:date, "no puede ser una fecha pasada")
        render :edit, status: :unprocessable_entity
        return
      end

      if @enrollment_section.update(enrollment_section_params)
        redirect_to admin_enrollment_path(@enrollment), notice: 'Clase actualizada exitosamente.'
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ArgumentError => e
      @enrollment_section.errors.add(:date, "formato inválido. Use DD/MM/YYYY")
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @enrollment = @enrollment_section.enrollment
      @enrollment_section.destroy
      redirect_to admin_enrollment_path(@enrollment), notice: 'Clase eliminada exitosamente.'
    end

    private

    def set_enrollment_section
      @enrollment_section = EnrollmentSection.find(params[:id])
    end

    def enrollment_section_params
      params.require(:enrollment_section).permit(:date, :section_id)
    end

    def makeup_params
      params.require(:enrollment_section).permit(:section_id, :date, :makeup_reason)
    end

    # Loads available sections of the same course + their upcoming dates with seats free
    def load_makeup_options
      course = @origin_section.course
      candidates = course.sections.includes(:teacher => :user).where.not(id: @origin_section.id)
      my_teacher_id = current_user.teacher&.id

      @contract_start, @contract_end = EnrollmentSection.contract_window_for(@enrollment)

      from = Date.current
      to = @contract_end && !current_admin? ? [@contract_end, from + 8.weeks].min : from + 8.weeks

      section_ids = candidates.map(&:id)
      seat_counts = if section_ids.any?
                      EnrollmentSection
                        .where(section_id: section_ids, date: from..to)
                        .group(:section_id, :date)
                        .count
                    else
                      {}
                    end

      # Fechas en las que el alumno ya tiene una clase agendada de esta misma inscripción
      # (sea regular o makeup, en cualquier sección): no se puede recuperar ahí porque
      # ya hay una clase de su plan ese día.
      already_scheduled_dates = EnrollmentSection
                                  .where(enrollment_id: @enrollment.id, date: from..to)
                                  .pluck(:date)
                                  .to_set

      weekday_map = Section::WEEKDAY_TO_WDAY

      @makeup_options = candidates.map do |section|
        wday = weekday_map[section.weekday]
        next nil if wday.nil?

        mine = current_admin? || section.teacher_id == my_teacher_id
        diff = (wday - from.wday) % 7
        first_date = from + diff
        dates = []
        (0..8).each do |k|
          d = first_date + (k * 7)
          break if d > to
          taken = seat_counts[[section.id, d]] || 0
          already_scheduled = already_scheduled_dates.include?(d)
          has_room = taken < section.places
          out_of_contract = @contract_start && @contract_end && (d < @contract_start || d > @contract_end)
          # El profe queda bloqueado fuera del período; el admin puede saltarse.
          period_block = out_of_contract && !current_admin?
          dates << {
            date: d,
            taken: taken,
            places: section.places,
            has_room: has_room,
            already_scheduled: already_scheduled,
            out_of_contract: out_of_contract,
            usable: mine && has_room && !already_scheduled && !period_block
          }
        end
        { section: section, dates: dates, mine: mine }
      end.compact
    end
  end
end
