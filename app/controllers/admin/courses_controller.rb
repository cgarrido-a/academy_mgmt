module Admin
  class CoursesController < Admin::ApplicationController
    before_action :set_course, only: [:show, :edit, :update, :destroy]

    def index
      @courses = Course.includes(:sections).all
    end

    def show
      @sections = @course.sections.includes(:teacher)
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

    private

    def set_course
      @course = Course.find(params[:id])
    end

    def course_params
      params.require(:course).permit(:title, :description)
    end
  end
end
