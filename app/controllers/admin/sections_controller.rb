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
      if @section.update(section_params)
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
      params.require(:section).permit(:course_id, :teacher_id, :places, :schedule, :start_date, :end_date)
    end
  end
end
