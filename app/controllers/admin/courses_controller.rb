module Admin
  class CoursesController < Admin::ApplicationController
    load_and_authorize_resource
    before_action :set_course, only: [:show, :edit, :update, :destroy]

    def index
      @courses = Course.includes(:sections).accessible_by(current_ability)
    end

    def show
      @sections = @course.sections.includes(:teacher).accessible_by(current_ability)
    end

    def new
      @course = Course.new
    end

    def create
      @course = Course.new(course_params)

      if @course.save
        redirect_to admin_course_path(@course), notice: 'Curso creado exitosamente.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @course.update(course_params)
        redirect_to admin_course_path(@course), notice: 'Curso actualizado exitosamente.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @course.destroy
      redirect_to admin_courses_path, notice: 'Curso eliminado exitosamente.'
    end

    def attendance
      @sections = @course.sections.accessible_by(current_ability)
                                  .includes(teacher: :user)
                                  .order(:weekday)

      @selected_section = @sections.find_by(id: params[:section_id]) if params[:section_id].present?
      @selected_date = (Date.parse(params[:date]) rescue nil) if params[:date].present?

      if @selected_section
        @class_dates = @selected_section.class_dates
        @attendance_by_date = can?(:take_attendance, @selected_section) ? @selected_section.attendance_counts_by_date : {}

        default_date = @selected_date || Date.current
        @year = (params[:year] || default_date.year).to_i
        @month = (params[:month] || default_date.month).to_i
        @calendar_date = Date.new(@year, @month, 1)
        @prev_month = @calendar_date.prev_month
        @next_month = @calendar_date.next_month
        @calendar_weeks = @selected_section.calendar_weeks_for(@calendar_date, selected_date: @selected_date, class_dates_set: @class_dates)
      end

      if @selected_section && @selected_date
        @enrollment_sections = @selected_section.enrollment_sections
                                                .includes(enrollment: { student: :user })
                                                .joins(enrollment: { student: :user })
                                                .where(date: @selected_date)
                                                .order('users.name')
      end
    end

    private

    def set_course
      @course = Course.find(params[:id])
    end

    def course_params
      params.require(:course).permit(:title, :description)
    end
  end
end
