module Admin
  class WeeklyPlansController < Admin::ApplicationController
    load_and_authorize_resource
    before_action :set_weekly_plan, only: [:show, :edit, :update, :destroy]
    before_action :load_courses, only: [:new, :create, :edit, :update]

    def index
      @weekly_plans = WeeklyPlan.includes(:course).order('course_id ASC NULLS LAST, id ASC')
    end

    def show
      @enrollments = @weekly_plan.enrollments.includes(student: :user, sections: :course)
    end

    def new
      @weekly_plan = WeeklyPlan.new
    end

    def create
      @weekly_plan = WeeklyPlan.new(weekly_plan_params)

      if @weekly_plan.save
        redirect_to admin_weekly_plans_path, notice: 'Plan semanal creado exitosamente.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @weekly_plan.update(weekly_plan_params)
        redirect_to admin_weekly_plans_path, notice: 'Plan semanal actualizado exitosamente.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @weekly_plan.enrollments.exists?
        redirect_to admin_weekly_plans_path, alert: 'No se puede eliminar un plan semanal con inscripciones asociadas.'
      else
        @weekly_plan.destroy
        redirect_to admin_weekly_plans_path, notice: 'Plan semanal eliminado exitosamente.'
      end
    end

    private

    def set_weekly_plan
      @weekly_plan = WeeklyPlan.find(params[:id])
    end

    def load_courses
      @courses = Course.order(:title)
    end

    def weekly_plan_params
      params.require(:weekly_plan).permit(:plan, :description, :price, :saturday_price, :enrollment_fee, :weekly_classes, :number_of_classes, :event_type, :course_id)
    end
  end
end
