module Api
  module V1
    class TeachersController < BaseController
      # GET /api/v1/teachers/:id/dashboard
      # Returns courses with their sections for a specific teacher
      def dashboard
        teacher = Teacher.find(params[:id])

        courses_data = courses_with_sections(teacher)

        render json: {
          success: true,
          data: {
            teacher: {
              id: teacher.id,
              name: teacher.user.name,
              profession: teacher.profession,
              email: teacher.user.email
            },
            courses: courses_data,
            summary: {
              total_courses: courses_data.length,
              total_sections: teacher.sections.count,
              total_students: total_students_count(teacher)
            }
          }
        }
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Teacher not found"
        }, status: :not_found
      end

      private

      def courses_with_sections(teacher)
        # Group sections by course
        sections_by_course = teacher.sections.includes(:course, :enrollment_sections).group_by(&:course)

        sections_by_course.map do |course, sections|
          {
            id: course.id,
            title: course.title,
            description: course.description,
            sections: sections.map { |section| section_data(section) }
          }
        end
      end

      def section_data(section)
        {
          id: section.id,
          schedule: section.schedule,
          formatted_schedule: section.formatted_schedule,
          weekday: section.weekday,
          total_places: section.places,
          enrolled_students: section.enrollments.count
        }
      end

      def total_students_count(teacher)
        # Count unique enrollments across all teacher's sections
        teacher.sections.joins(:enrollments).select('enrollments.id').distinct.count
      end
    end
  end
end
