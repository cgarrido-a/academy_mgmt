module Admin
  class SectionsController < Admin::ApplicationController
    load_and_authorize_resource
    before_action :set_section, only: [:show, :edit, :update, :destroy, :suspend_session, :apply_suspension]

    def index
      weekday_order = "CASE weekday WHEN 'Lunes' THEN 1 WHEN 'Martes' THEN 2 WHEN 'Miércoles' THEN 3 WHEN 'Jueves' THEN 4 WHEN 'Viernes' THEN 5 WHEN 'Sábado' THEN 6 WHEN 'Domingo' THEN 7 END"
      @sections = Section.includes(:course, teacher: :user).accessible_by(current_ability).order(Arel.sql(weekday_order))

      @courses = Course.joins(:sections).merge(Section.accessible_by(current_ability)).distinct.order(:title)
      @selected_course_id = params[:course_id].presence&.to_i
      @sections = @sections.where(course_id: @selected_course_id) if @selected_course_id

      section_ids = @sections.map(&:id)

      @student_counts = EnrollmentSection
        .where(section_id: section_ids)
        .group(:section_id)
        .distinct
        .count(:enrollment_id)

      @next_class_dates = EnrollmentSection
        .where(section_id: section_ids)
        .where('date >= ?', Date.current)
        .group(:section_id)
        .minimum(:date)
    end

    def show
      # Get all dates with enrollments for this section
      @section_dates = @section.enrollment_sections
                               .select(:date)
                               .distinct
                               .pluck(:date)
                               .to_set

      # Selected date (needed before calendar setup to determine which month to show)
      if params[:date].present?
        @selected_date = Date.parse(params[:date])
      end

      # Calendar setup - use selected date's month if no explicit month param
      @current_date = Date.current
      default_date = @selected_date || @current_date
      @year = (params[:year] || default_date.year).to_i
      @month = (params[:month] || default_date.month).to_i
      @calendar_date = Date.new(@year, @month, 1)

      # Attendance status per date for calendar indicators
      if can? :take_attendance, @section
        attendance_data = @section.enrollment_sections
          .where(date: @section_dates.to_a)
          .group(:date)
          .pluck(:date, Arel.sql('COUNT(*)'), Arel.sql('COUNT(CASE WHEN attended = true THEN 1 END)'))
        @attendance_by_date = attendance_data.each_with_object({}) do |(date, total, present), hash|
          hash[date] = { total: total, present: present }
        end
      else
        @attendance_by_date = {}
      end

      # Build mini calendar
      @calendar_weeks = build_section_calendar(@calendar_date)

      # Navigation
      @prev_month = @calendar_date.prev_month
      @next_month = @calendar_date.next_month

      # If no date was provided, default to today or next date with enrollments
      unless @selected_date
        today = Date.current
        @selected_date = @section_dates.include?(today) ? today : @section_dates.select { |d| d >= today }.min
        @selected_date ||= @section_dates.max
      end

      # Get enrollments for the selected date
      if @selected_date
        @enrollment_sections = @section.enrollment_sections
                                       .includes(:makeup, { makes_up_for: :section }, enrollment: { student: :user })
                                       .where(date: @selected_date)
                                       .order('users.name')
      else
        @enrollment_sections = []
      end

      # Permiso para marcar asistencia en esta fecha:
      # - Admin puede marcar cualquier fecha
      # - Profe solo de hoy en adelante
      @can_mark_attendance = can?(:take_attendance, @section) &&
                             @selected_date.present? &&
                             (current_admin? || @selected_date >= Date.current)

      # Quick-nav fechas: ventana de 8 fechas (3 antes + 5 después de la referencia).
      # La referencia es @selected_date si existe, si no hoy. Se puede desplazar con dates_offset.
      sorted_dates = @section_dates.to_a.sort
      window_size = 8
      past_count = 3

      ref_date = @selected_date || Date.current
      ref_index = sorted_dates.index { |d| d >= ref_date } || sorted_dates.size

      offset = params[:dates_offset].to_i
      start_idx = [ref_index - past_count + offset, 0].max
      end_idx = [start_idx + window_size, sorted_dates.size].min
      start_idx = [end_idx - window_size, 0].max

      @quick_dates = sorted_dates[start_idx...end_idx] || []
      @quick_dates_has_prev = start_idx > 0
      @quick_dates_has_next = end_idx < sorted_dates.size
      @quick_dates_prev_offset = offset - window_size
      @quick_dates_next_offset = offset + window_size
      @quick_dates_offset = offset

      # Stats agregados del día seleccionado
      if @selected_date && @enrollment_sections.any?
        @day_present = @enrollment_sections.count { |es| es.attended == true }
        @day_absent  = @enrollment_sections.count { |es| es.attended == false }
        @day_pending = @enrollment_sections.count { |es| es.attended.nil? }
        marked = @day_present + @day_absent
        @day_rate = marked.positive? ? ((@day_present.to_f / marked) * 100).round : nil
      end

      # % asistencia histórica de cada estudiante en esta sección
      enrollment_ids = @enrollment_sections.map(&:enrollment_id)
      if enrollment_ids.any?
        rows = @section.enrollment_sections
                       .where(enrollment_id: enrollment_ids)
                       .where.not(attended: nil)
                       .group(:enrollment_id)
                       .pluck(
                         :enrollment_id,
                         Arel.sql('COUNT(*)'),
                         Arel.sql('COUNT(CASE WHEN attended = true THEN 1 END)')
                       )
        @student_attendance_stats = rows.each_with_object({}) do |(eid, total, present), h|
          h[eid] = { total: total, present: present, rate: total.positive? ? ((present.to_f / total) * 100).round : nil }
        end
      else
        @student_attendance_stats = {}
      end
    end

    def build_section_calendar(date)
      first_day = date.beginning_of_month
      last_day = date.end_of_month
      start_date = first_day.beginning_of_week(:monday)
      end_date = last_day.end_of_week(:monday)

      # Map section weekday to wday number
      weekday_map = {
        'Domingo' => 0, 'Lunes' => 1, 'Martes' => 2, 'Miércoles' => 3,
        'Jueves' => 4, 'Viernes' => 5, 'Sábado' => 6
      }
      section_wday = weekday_map[@section.weekday]

      weeks = []
      current = start_date

      while current <= end_date
        week = (0..6).map do |i|
          day = current + i
          has_enrollments = @section_dates.include?(day)
          is_section_day = day.wday == section_wday
          {
            date: day,
            in_month: day.month == date.month,
            is_today: day == Date.current,
            has_class: has_enrollments,
            is_section_day: is_section_day,
            is_selected: day == @selected_date
          }
        end
        weeks << week
        current += 7
      end

      weeks
    end

    def new
      @section = Section.new
      @courses = Course.all
      @teachers = Teacher.includes(:user).all
    end

    def create
      @section = Section.new(section_params)
      process_schedule_params

      if @section.save
        redirect_to admin_section_path(@section), notice: 'Sección creada exitosamente.'
      else
        @courses = Course.all
        @teachers = Teacher.includes(:user).all
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @courses = Course.all
      @teachers = Teacher.includes(:user).all
    end

    def update
      @section.assign_attributes(section_params)
      process_schedule_params

      if @section.save
        redirect_to admin_section_path(@section), notice: 'Sección actualizada exitosamente.'
      else
        @courses = Course.all
        @teachers = Teacher.includes(:user).all
        render :edit, status: :unprocessable_entity
      end
    end

    def take_attendance
      @section = Section.find(params[:id])
      authorize! :take_attendance, @section

      date = params[:date]
      parsed_date = Date.parse(date) rescue nil

      if current_teacher? && parsed_date && parsed_date < Date.current
        redirect_back fallback_location: admin_section_path(@section, date: date),
                      alert: 'Solo puedes marcar asistencia de hoy en adelante.'
        return
      end

      attendance_params = params.require(:attendance)

      attendance_params.each do |es_id, attrs|
        es = @section.enrollment_sections.find(es_id)
        es.update!(attended: attrs[:attended] == "1")
      end

      if params[:course_id].present?
        redirect_to attendance_admin_course_path(params[:course_id], section_id: @section.id, date: date),
                    notice: 'Asistencia guardada exitosamente.'
      else
        redirect_to admin_section_path(@section, date: date), notice: 'Asistencia guardada exitosamente.'
      end
    end

    def destroy
      @section.destroy
      redirect_to admin_sections_path, notice: 'Sección eliminada exitosamente.'
    end

    # GET /admin/sections/:id/suspend_session?date=YYYY-MM-DD
    # Pantalla de confirmación: alumnos afectados + fecha a la que caería cada uno.
    def suspend_session
      @date = parse_session_date(params[:date])
      return if @date.nil?

      @cohort = @section.enrollment_sections
                        .includes(enrollment: { student: :user })
                        .where(date: @date)
                        .order('users.name')

      if @cohort.empty?
        redirect_to admin_section_path(@section, date: @date),
                    alert: 'No hay clases en esa fecha para suspender.'
        return
      end

      suspender = SessionSuspender.new(section: @section, date: @date, reason: nil, admin_user: current_user)
      @preview = @cohort.each_with_object({}) do |es, h|
        h[es.id] = es.attended.nil? ? suspender.target_date_for(es.enrollment) : nil
      end
    end

    # POST /admin/sections/:id/apply_suspension
    def apply_suspension
      @date = parse_session_date(params[:date])
      return if @date.nil?

      result = SessionSuspender.new(
        section: @section,
        date: @date,
        reason: params[:reason].presence,
        admin_user: current_user
      ).call

      msg = "Clase del #{I18n.l(@date, format: '%d/%m/%Y')} suspendida. " \
            "#{result.moved.size} alumno(s) reprogramado(s) al final de su plan."
      if result.skipped.any?
        msg += " #{result.skipped.size} sin mover (#{result.skipped.map { |s| s[:reason] }.uniq.join(', ')})."
      end
      redirect_to admin_section_path(@section, date: @date), notice: msg
    rescue StandardError => e
      redirect_to admin_section_path(@section, date: @date),
                  alert: "No se pudo suspender la clase: #{e.message}"
    end

    private

    def set_section
      @section = Section.find(params[:id])
    end

    # Parsea la fecha de la sesión; si es inválida redirige y devuelve nil
    # (el caller debe hacer `return if ... .nil?`).
    def parse_session_date(raw)
      Date.parse(raw.to_s)
    rescue ArgumentError, TypeError
      redirect_to admin_section_path(@section), alert: 'Fecha inválida.'
      nil
    end

    def section_params
      params.require(:section).permit(:course_id, :teacher_id, :places, :weekday)
    end

    def process_schedule_params
      # Process schedule array from form
      if params[:section] && params[:section][:schedule].present?
        schedule_data = params[:section][:schedule]

        # Filter out empty entries and convert to proper format
        @section.schedule = schedule_data.select { |entry|
          entry[:start_time].present? && entry[:end_time].present?
        }.map { |entry|
          {
            'start_time' => entry[:start_time],
            'end_time' => entry[:end_time]
          }
        }
      end
    end
  end
end
