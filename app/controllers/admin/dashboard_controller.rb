module Admin
  class DashboardController < Admin::ApplicationController
    authorize_resource class: false

    def index
      @total_courses = Course.count
      @total_sections = Section.count
      @total_students = Student.count
      @total_enrollments = Enrollment.count
      @recent_enrollments = Enrollment.includes(student: :user, sections: :course)
                                       .order(created_at: :desc)
                                       .limit(10)
    end

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
