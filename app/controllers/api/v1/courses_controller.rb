module Api
  module V1
    class CoursesController < BaseController
      # GET /api/v1/courses
      def index
        courses = Course.includes(:sections).all

        render json: {
          success: true,
          data: courses.map { |course| course_with_sections(course) }
        }
      end

      private

      def course_with_sections(course)
        {
          id: course.id,
          title: course.title,
          description: course.description,
          sections: course.sections.map { |section| section_data(section) }
        }
      end

      def section_data(section)
        {
          id: section.id,
          schedule: section.schedule,
          start_date: section.start_date,
          end_date: section.end_date,
          places: section.places,
          available_places: section.available_places,
          teacher_name: section.teacher.user.name
        }
      end
    end
  end
end
