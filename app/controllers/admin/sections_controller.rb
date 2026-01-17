module Admin
  class SectionsController < Admin::ApplicationController
    load_and_authorize_resource
    before_action :set_section, only: [:show, :edit, :update, :destroy]

    def index
      @sections = Section.includes(:course, :teacher).accessible_by(current_ability)
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
                                       .includes(enrollment: { student: :user })
                                       .where(date: @selected_date)
                                       .order('users.name')
      else
        @enrollment_sections = []
      end
    end

    def build_section_calendar(date)
      first_day = date.beginning_of_month
      last_day = date.end_of_month
      start_date = first_day.beginning_of_week(:monday)
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
            has_class: @section_dates.include?(day),
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

    def destroy
      @section.destroy
      redirect_to admin_sections_path, notice: 'Sección eliminada exitosamente.'
    end

    private

    def set_section
      @section = Section.find(params[:id])
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
