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
      # Un usuario puede tener varios roles: cargamos los datos de cada uno
      # de forma independiente.
      load_teacher_data if @user.teacher.present?
      load_student_data if @user.student.present?
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      User.transaction do
        @user.save!
        sync_roles!(@user)
      end

      redirect_to admin_user_path(@user), notice: 'Usuario creado exitosamente.'
    rescue ActiveRecord::RecordInvalid => e
      @user.errors.add(:base, e.message) if @user.errors.empty?
      render :new, status: :unprocessable_entity
    end

    def edit
    end

    def update
      User.transaction do
        @user.update!(user_params)
        sync_roles!(@user)
      end

      redirect_to admin_user_path(@user), notice: 'Usuario actualizado exitosamente.'
    rescue ActiveRecord::RecordInvalid => e
      @user.errors.add(:base, e.message) if @user.errors.empty?
      render :edit, status: :unprocessable_entity
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
      permitted = params.require(:user).permit(:name, :email, :password)
      # En edición, dejar la contraseña en blanco significa "no cambiarla".
      permitted.delete(:password) if permitted[:password].blank?
      permitted
    end

    # Asigna los roles marcados en el formulario. Es aditivo: crea los registros
    # de rol que falten, pero NO elimina roles existentes (quitar docente o
    # estudiante haría dependent: :destroy en cascada). También actualiza la
    # profesión / tipo de admin de los roles ya presentes.
    def sync_roles!(user)
      selected = Array(params.dig(:user, :roles))

      user.create_student!                                            if selected.include?('student') && user.student.nil?
      user.create_teacher!(profession: params.dig(:user, :profession)) if selected.include?('teacher') && user.teacher.nil?
      user.create_admin_user!(admin_type: params.dig(:user, :admin_type)) if selected.include?('admin') && user.admin_user.nil?

      if user.teacher && params.dig(:user, :profession).present?
        user.teacher.update!(profession: params[:user][:profession])
      end
      if user.admin_user && params.dig(:user, :admin_type).present?
        user.admin_user.update!(admin_type: params[:user][:admin_type])
      end
    end

    def load_student_data
      student = @user.student
      @student_enrollments = student.enrollments
                                    .includes(:weekly_plan, :payment_method, :payments,
                                              enrollment_sections: { section: :course })
                                    .order(created_at: :desc)

      # Agregados de asistencia: regular = clases del plan; makeup = recuperatorios
      regular_total = 0
      regular_present = 0
      makeup_present = 0
      total_to_pay = 0
      total_paid = 0
      makeup_total = 0

      @student_enrollments.each do |enr|
        regulars = enr.enrollment_sections.select(&:regular?)
        makeups  = enr.enrollment_sections.select(&:makeup?)
        regular_total   += regulars.size
        regular_present += regulars.count { |es| es.attended == true }
        makeup_total    += makeups.size
        makeup_present  += makeups.count { |es| es.attended == true }

        total_to_pay += enr.enrollment_amount.to_i + enr.total_tuition_fee.to_i
        total_paid   += enr.payments.select { |p| p.status == 'completed' }.sum(&:amount).to_i
      end

      @student_total_classes     = regular_total
      @student_attendance_rate   = regular_total.positive? ? ((regular_present + makeup_present).to_f / regular_total * 100).round : nil
      @student_makeup_total      = makeup_total
      @student_total_to_pay      = total_to_pay
      @student_total_paid        = total_paid
      @student_balance           = total_to_pay - total_paid
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
