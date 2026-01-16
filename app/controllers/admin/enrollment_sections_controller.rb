module Admin
  class EnrollmentSectionsController < Admin::ApplicationController
    load_and_authorize_resource
    before_action :set_enrollment_section, only: [:edit, :update, :destroy]

    def edit
      @enrollment = @enrollment_section.enrollment
      @section = @enrollment_section.section
      @sections = Section.includes(:course, teacher: :user).all
    end

    def update
      @enrollment = @enrollment_section.enrollment
      @sections = Section.includes(:course, teacher: :user).all

      # Obtener la sección (puede ser la nueva o la actual)
      new_section_id = enrollment_section_params[:section_id] || @enrollment_section.section_id
      @section = Section.find(new_section_id)

      new_date = Date.parse(enrollment_section_params[:date])

      # Validar día de la semana con la nueva sección
      weekday_map = {
        'Domingo' => 0,
        'Lunes' => 1,
        'Martes' => 2,
        'Miércoles' => 3,
        'Jueves' => 4,
        'Viernes' => 5,
        'Sábado' => 6
      }
      target_wday = weekday_map[@section.weekday]

      unless new_date.wday == target_wday
        @enrollment_section.errors.add(:date, "debe ser un #{@section.weekday}")
        render :edit, status: :unprocessable_entity
        return
      end

      # Validar fecha futura
      if new_date < Date.today
        @enrollment_section.errors.add(:date, "no puede ser una fecha pasada")
        render :edit, status: :unprocessable_entity
        return
      end

      if @enrollment_section.update(enrollment_section_params)
        redirect_to admin_enrollment_path(@enrollment), notice: 'Clase actualizada exitosamente.'
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ArgumentError => e
      @enrollment_section.errors.add(:date, "formato inválido. Use DD/MM/YYYY")
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @enrollment = @enrollment_section.enrollment
      @enrollment_section.destroy
      redirect_to admin_enrollment_path(@enrollment), notice: 'Clase eliminada exitosamente.'
    end

    private

    def set_enrollment_section
      @enrollment_section = EnrollmentSection.find(params[:id])
    end

    def enrollment_section_params
      params.require(:enrollment_section).permit(:date, :section_id)
    end
  end
end
