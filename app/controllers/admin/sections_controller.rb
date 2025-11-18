module Admin
  class SectionsController < Admin::ApplicationController
    before_action :set_section, only: [:show, :edit, :update, :destroy]

    def index
      @sections = Section.includes(:course, :teacher).all
    end

    def show
      @enrollments = @section.enrollments.includes(student: :user)
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
      params.require(:section).permit(:course_id, :teacher_id, :places, :date)
    end

    def process_schedule_params
      # Process schedule array from form
      if params[:section] && params[:section][:schedule].present?
        schedule_data = params[:section][:schedule]

        # Filter out empty entries and convert to proper format
        @section.schedule = schedule_data.select { |entry|
          entry[:day].present? && entry[:start_time].present? && entry[:end_time].present?
        }.map { |entry|
          {
            'day' => entry[:day],
            'start_time' => entry[:start_time],
            'end_time' => entry[:end_time]
          }
        }
      end
    end
  end
end
