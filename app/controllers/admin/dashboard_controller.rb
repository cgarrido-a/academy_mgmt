module Admin
  class DashboardController < Admin::ApplicationController
    def index
      @total_courses = Course.count
      @total_sections = Section.count
      @total_students = Student.count
      @total_enrollments = Enrollment.count
      @recent_enrollments = Enrollment.includes(student: :user, sections: :course)
                                       .order(created_at: :desc)
                                       .limit(10)
    end
  end
end
