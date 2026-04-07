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

      # Attendance summary
      all_section_ids = @teacher_sections.map(&:id)
      month_start = @calendar_date.beginning_of_month
      month_end = @calendar_date.end_of_month

      month_es = EnrollmentSection.where(section_id: all_section_ids, date: month_start..month_end)
      @month_total = month_es.count
      @month_present = month_es.where(attended: true).count
      @month_absent = month_es.where(attended: false).count
      @month_pending = month_es.where(attended: nil).count
      @month_attendance_rate = @month_total > 0 ? ((@month_present.to_f / (@month_present + @month_absent)) * 100).round(0) : nil

      # Per-section attendance for the month
      @section_attendance = month_es
        .group(:section_id)
        .pluck(:section_id, Arel.sql('COUNT(*)'), Arel.sql('COUNT(CASE WHEN attended = true THEN 1 END)'), Arel.sql('COUNT(CASE WHEN attended = false THEN 1 END)'))
        .map do |sid, total, present, absent|
          section = @teacher_sections.find { |s| s.id == sid }
          registered = total > 0 ? present + absent : 0
          rate = registered > 0 ? ((present.to_f / registered) * 100).round(0) : nil
          { section: section, total: total, present: present, absent: absent, rate: rate }
        end
        .sort_by { |s| s[:section].weekday }

      # Upcoming classes without attendance (pending)
      @pending_dates = EnrollmentSection
        .where(section_id: all_section_ids, attended: nil)
        .where('date <= ?', Date.current)
        .group(:section_id, :date)
        .pluck(:section_id, :date, Arel.sql('COUNT(*)'))
        .map do |sid, date, count|
          section = @teacher_sections.find { |s| s.id == sid }
          { section: section, date: date, count: count }
        end
        .sort_by { |p| p[:date] }
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

      # Monthly teacher report
      @current_date = Date.current
      @report_year = (params[:year] || @current_date.year).to_i
      @report_month = (params[:month] || @current_date.month).to_i
      @report_date = Date.new(@report_year, @report_month, 1)
      @report_prev = @report_date.prev_month
      @report_next = @report_date.next_month

      month_start = @report_date.beginning_of_month
      month_end = @report_date.end_of_month

      # Get all enrollment_sections for the month grouped by teacher
      teacher_data = EnrollmentSection
        .joins(section: { teacher: :user })
        .where(date: month_start..month_end)
        .group('teachers.id', 'users.name')
        .pluck(
          Arel.sql('teachers.id'),
          Arel.sql('users.name'),
          Arel.sql('COUNT(DISTINCT enrollment_sections.section_id)'),
          Arel.sql('COUNT(DISTINCT enrollment_sections.date)'),
          Arel.sql('COUNT(*)'),
          Arel.sql('COUNT(DISTINCT enrollment_sections.enrollment_id)'),
          Arel.sql('COUNT(CASE WHEN enrollment_sections.attended = true THEN 1 END)'),
          Arel.sql('COUNT(CASE WHEN enrollment_sections.attended = false THEN 1 END)')
        )

      @teacher_report = teacher_data.map do |teacher_id, name, sections, class_dates, total_entries, students, present, absent|
        registered = present + absent
        rate = registered > 0 ? ((present.to_f / registered) * 100).round(0) : nil
        {
          teacher_id: teacher_id, name: name, sections: sections,
          class_dates: class_dates, total_entries: total_entries,
          students: students, present: present, absent: absent, rate: rate
        }
      end.sort_by { |t| t[:name] }

      @report_totals = {
        sections: @teacher_report.sum { |t| t[:sections] },
        class_dates: @teacher_report.sum { |t| t[:class_dates] },
        total_entries: @teacher_report.sum { |t| t[:total_entries] },
        students: @teacher_report.sum { |t| t[:students] },
        present: @teacher_report.sum { |t| t[:present] },
        absent: @teacher_report.sum { |t| t[:absent] }
      }
      registered_total = @report_totals[:present] + @report_totals[:absent]
      @report_totals[:rate] = registered_total > 0 ? ((@report_totals[:present].to_f / registered_total) * 100).round(0) : nil
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
