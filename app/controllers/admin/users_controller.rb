module Admin
  class UsersController < Admin::ApplicationController
    load_and_authorize_resource
    before_action :set_user, only: [:show, :edit, :update, :destroy]

    def index
      @filter = params[:filter] || 'all'

      @users = User.includes(:student, :teacher, :admin_user)

      case @filter
      when 'students'
        @users = @users.joins(:student)
      when 'teachers'
        @users = @users.joins(:teacher)
      when 'admins'
        @users = @users.joins(:admin_user)
      end

      @users = @users.all

      # Contar por roles
      @total_users = User.count
      @total_students = Student.count
      @total_teachers = Teacher.count
      @total_admins = AdminUser.count
    end

    def show
      @role = determine_role(@user)

      if @user.teacher.present?
        load_teacher_data
      end
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save
        begin
          # Create the corresponding role record
          case params[:user][:role]
          when 'student'
            @user.create_student!
          when 'teacher'
            @user.create_teacher!(profession: params[:user][:profession])
          when 'admin'
            @user.create_admin_user!(admin_type: params[:user][:admin_type])
          end

          redirect_to admin_users_path, notice: 'Usuario creado exitosamente.'
        rescue ActiveRecord::RecordInvalid => e
          flash.now[:alert] = "Error al crear el rol: #{e.message}"
          render :new, status: :unprocessable_entity
        rescue => e
          flash.now[:alert] = "Error: #{e.message}"
          render :new, status: :unprocessable_entity
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @role = determine_role(@user)
    end

    def update
      if @user.update(user_params)
        redirect_to admin_user_path(@user), notice: 'Usuario actualizado exitosamente.'
      else
        @role = determine_role(@user)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @user.destroy
      redirect_to admin_users_path, notice: 'Usuario eliminado exitosamente.'
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:name, :email, :password)
    end

    def determine_role(user)
      return 'teacher' if user.teacher.present?
      return 'student' if user.student.present?
      return 'admin' if user.admin_user.present?
      'none'
    end

    def load_teacher_data
      teacher = @user.teacher
      @teacher_sections = teacher.sections.includes(:course).order(:weekday)
      @teacher_courses = @teacher_sections.map(&:course).uniq.sort_by(&:title)

      # Obtener todos los estudiantes únicos del profesor
      @teacher_students = Student.joins(enrollments: { enrollment_sections: :section })
                                 .where(sections: { teacher_id: teacher.id })
                                 .includes(:user)
                                 .distinct
                                 .order('users.name')

      # Contar estudiantes por sección
      @students_count_by_section = EnrollmentSection.joins(:section)
                                                    .where(sections: { teacher_id: teacher.id })
                                                    .group(:section_id)
                                                    .select('section_id, COUNT(DISTINCT enrollment_id) as count')
                                                    .index_by(&:section_id)
    end
  end
end
