module Api
  module V1
    class CoursesController < BaseController
      # GET /api/v1/courses
      # Optional params: date (YYYY-MM-DD) to check availability for a specific date
      def index
        courses = Course.includes(:sections).all
        date = params[:date]

        render json: {
          success: true,
          data: courses.map { |course| course_with_sections(course, date) }
        }
      end

      private

      def course_with_sections(course, date = nil)
        {
          id: course.id,
          title: course.title,
          description: course.description,
          active: course.active,
          sections: course.sections.map { |section| section_data(section, date) }
        }
      end

      def section_data(section, date = nil)
        data = {
          id: section.id,
          schedule: section.schedule,
          weekday: section.weekday,
          places: section.places,
          teacher_name: section.teacher.user.name
        }

        # If a specific date is provided, show availability for that date
        if date.present?
          parsed_date = Date.parse(date)
          data[:date] = parsed_date
          data[:available_places] = section.available_places_for_date(parsed_date)
        else
          # Without a date, we can't accurately show available places
          # since it varies by date
          data[:available_places] = nil
          data[:note] = "Provide a date parameter to see availability"
        end

        data
      rescue ArgumentError
        # If date parsing fails, just return basic info
        data[:available_places] = nil
        data[:error] = "Invalid date format"
        data
      end
    end
  end
end
