module Admin
  class DashboardController < Admin::ApplicationController
    authorize_resource class: false

    WEEKDAYS = %w[Lunes Martes Miércoles Jueves Viernes Sábado Domingo].freeze
    WEEKDAY_MAP = {
      'Lunes' => 1, 'Martes' => 2, 'Miércoles' => 3, 'Jueves' => 4,
      'Viernes' => 5, 'Sábado' => 6, 'Domingo' => 0
    }.freeze

    def index
      if current_teacher?
        load_teacher_dashboard
      else
        load_admin_dashboard
      end
    end

    private

    def load_teacher_dashboard
      teacher = current_user.teacher
      @teacher_sections = teacher.sections.includes(:course).order(:weekday)

      # Get unique courses for filter buttons
      @teacher_courses = @teacher_sections.map(&:course).uniq.sort_by(&:title)

      # Filter by course if selected
      @selected_course_id = params[:course_id].present? ? params[:course_id].to_i : nil
      filtered_sections = @selected_course_id ? @teacher_sections.select { |s| s.course_id == @selected_course_id } : @teacher_sections

      # Build sections by weekday number for calendar lookup
      @sections_by_wday = Hash.new { |h, k| h[k] = [] }
      filtered_sections.each do |section|
        wday = WEEKDAY_MAP[section.weekday]
        @sections_by_wday[wday] << section if wday
      end

      # Calendar setup
      @current_date = Date.current
      @year = (params[:year] || @current_date.year).to_i
      @month = (params[:month] || @current_date.month).to_i
      @calendar_date = Date.new(@year, @month, 1)

      # Pre-calculate student counts per section and date for this month
      start_date = @calendar_date.beginning_of_month.beginning_of_week(:monday)
      end_date = @calendar_date.end_of_month.end_of_week(:monday)
      section_ids = filtered_sections.map(&:id)

      @students_by_section_date = EnrollmentSection
        .where(section_id: section_ids, date: start_date..end_date)
        .group(:section_id, :date)
        .count

      @calendar_weeks = build_calendar_weeks(@calendar_date)

      # Navigation
      @prev_month = @calendar_date.prev_month
      @next_month = @calendar_date.next_month

      # Stats
      @total_sections = @teacher_sections.count
      @total_students = @teacher_sections.joins(:enrollments).select('enrollments.student_id').distinct.count
    end

    def build_calendar_weeks(date)
      first_day = date.beginning_of_month
      last_day = date.end_of_month

      # Start from the Monday of the first week
      start_date = first_day.beginning_of_week(:monday)
      # End on Sunday of the last week
      end_date = last_day.end_of_week(:monday)

      weeks = []
      current = start_date

      while current <= end_date
        week = (0..6).map do |i|
          day = current + i
          {
            date: day,
            in_month: day.month == date.month,
            is_today: day == Date.current,
            sections: @sections_by_wday[day.wday] || []
          }
        end
        weeks << week
        current += 7
      end

      weeks
    end

    def load_admin_dashboard
      @total_courses = Course.count
      @total_sections = Section.count
      @total_students = Student.count
      @total_enrollments = Enrollment.count
      @recent_enrollments = Enrollment.includes(student: :user, sections: :course)
                                       .order(created_at: :desc)
                                       .limit(10)
    end

    public

    def export
      csv_data = FinancialReportCsvExporter.call

      respond_to do |format|
        format.csv do
          send_data csv_data,
                    filename: "reporte_financiero_#{Date.today.strftime('%Y%m%d')}.csv",
                    type: 'text/csv; charset=utf-8'
        end
      end
    end
  end
end
