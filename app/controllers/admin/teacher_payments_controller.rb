class Admin::TeacherPaymentsController < Admin::ApplicationController
  def index
    @teachers = Teacher.includes(:user, sections: { enrollment_sections: :enrollment }).all
    @payments_by_teacher_and_month = {}

    # Obtener meses disponibles
    @available_months = Enrollment.joins(enrollment_sections: :section)
                                  .distinct
                                  .pluck(:created_at)
                                  .map { |d| d.beginning_of_month }
                                  .uniq
                                  .sort
                                  .reverse

    @selected_month = params[:month].present? ? Date.parse(params[:month]) : nil
    @selected_status = params[:status]

    @teachers.each do |teacher|
      enrollments = Enrollment.joins(enrollment_sections: :section)
                              .where(sections: { teacher_id: teacher.id })
                              .distinct

      if @selected_month
        enrollments = enrollments.where(created_at: @selected_month.beginning_of_month..@selected_month.end_of_month)
      end

      grouped = enrollments.group_by { |e| e.created_at.beginning_of_month }

      # Filtrar por estado del pago
      if @selected_status.present?
        grouped = grouped.select do |month, _|
          payment = TeacherPayment.find_by(teacher_id: teacher.id, period_start: month.beginning_of_month, period_end: month.end_of_month)
          if @selected_status == 'paid'
            payment&.status == 'paid'
          else
            payment.nil? || payment.status != 'paid'
          end
        end
      end

      @payments_by_teacher_and_month[teacher] = grouped if grouped.any?
    end
  end

  def show
    @teacher = Teacher.includes(:user).find(params[:id])
    @month = Date.parse(params[:month])

    @courses = Course.joins(sections: :teacher)
                     .where(sections: { teacher_id: @teacher.id })
                     .distinct

    @enrollments = Enrollment.joins(enrollment_sections: :section)
                             .includes(student: :user, weekly_plan: [], enrollment_sections: { section: :course })
                             .where(sections: { teacher_id: @teacher.id })
                             .where(created_at: @month.beginning_of_month..@month.end_of_month)
                             .distinct

    if params[:course_id].present?
      @enrollments = @enrollments.where(sections: { course_id: params[:course_id] })
      @selected_course = params[:course_id].to_i
    end

    @total_tuition = @enrollments.sum(&:total_tuition_fee)
    @payment_amount = @total_tuition * 0.425
  end

  def toggle_status
    @teacher = Teacher.find(params[:id])
    month = Date.parse(params[:month])
    new_status = params[:new_status]

    # Calcular el monto a pagar
    enrollments = Enrollment.joins(enrollment_sections: :section)
                            .where(sections: { teacher_id: @teacher.id })
                            .where(created_at: month.beginning_of_month..month.end_of_month)
                            .distinct
    total_tuition = enrollments.sum(&:total_tuition_fee)
    payment_amount = (total_tuition * 0.425).to_i

    # Buscar o crear el pago
    payment = TeacherPayment.find_or_initialize_by(
      teacher_id: @teacher.id,
      period_start: month.beginning_of_month,
      period_end: month.end_of_month
    )

    # Asignar valores
    payment.amount = payment_amount if payment.new_record?
    payment.payment_method_id ||= PaymentMethod.first&.id
    payment.status = new_status
    payment.payment_date = new_status == 'paid' ? Date.current : nil

    if payment.save
      redirect_to admin_teacher_payments_path(month: params[:filter_month], status: params[:filter_status]),
                  notice: "Estado actualizado correctamente."
    else
      redirect_to admin_teacher_payments_path(month: params[:filter_month], status: params[:filter_status]),
                  alert: "Error al actualizar el estado."
    end
  end
end
