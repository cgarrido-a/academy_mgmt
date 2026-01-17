module Admin
  class DashboardController < Admin::ApplicationController
    authorize_resource class: false

    WEEKDAYS = %w[Lunes Martes Miércoles Jueves Viernes Sábado Domingo].freeze

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
      @sections_by_weekday = WEEKDAYS.index_with { |_| [] }

      @teacher_sections.each do |section|
        @sections_by_weekday[section.weekday] << section if @sections_by_weekday.key?(section.weekday)
      end

      @total_sections = @teacher_sections.count
      @total_students = @teacher_sections.joins(:enrollments).select('enrollments.student_id').distinct.count
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
