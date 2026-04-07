class Admin::TeacherPaymentsController < Admin::ApplicationController
  def index
    # Available months
    @available_months = EnrollmentSection.joins(:enrollment)
                                         .select('DISTINCT DATE_TRUNC(\'month\', enrollments.created_at) as month_date')
                                         .map { |r| r.month_date.to_date }
                                         .sort
                                         .reverse

    # Default to current month if no month selected
    if params[:month].present?
      @selected_month = Date.parse(params[:month])
    else
      @selected_month = @available_months.first || Date.current.beginning_of_month
    end

    @selected_status = params[:status]

    # Navigation
    month_index = @available_months.index(@selected_month.beginning_of_month)
    if month_index
      @nav_next = month_index > 0 ? @available_months[month_index - 1] : nil
      @nav_prev = month_index < @available_months.size - 1 ? @available_months[month_index + 1] : nil
    else
      @nav_prev = @selected_month.prev_month
      @nav_next = @selected_month.next_month
    end

    # Build teacher rows
    teachers = Teacher.includes(:user).all
    @teacher_rows = []

    teachers.each do |teacher|
      enrollments = Enrollment.joins(enrollment_sections: :section)
                              .where(sections: { teacher_id: teacher.id })
                              .distinct

      if @selected_month
        enrollments = enrollments.where(created_at: @selected_month.beginning_of_month..@selected_month.end_of_month)
      end

      next if enrollments.empty?

      grouped = enrollments.group_by { |e| e.created_at.beginning_of_month }

      grouped.each do |month, month_enrollments|
        payment = TeacherPayment.find_by(teacher_id: teacher.id, period_start: month.beginning_of_month, period_end: month.end_of_month)
        status = payment&.status || 'pending'

        next if @selected_status.present? && status != @selected_status

        tuition_total = month_enrollments.sum(&:total_tuition_fee)
        payment_amount = tuition_total * 0.425

        @teacher_rows << {
          teacher: teacher,
          name: teacher.user.name,
          month: month,
          enrollment_count: month_enrollments.size,
          tuition_total: tuition_total,
          payment_amount: payment_amount,
          status: status
        }
      end
    end

    @teacher_rows.sort_by! { |r| r[:name] }

    # Summary totals
    @summary = {
      teachers: @teacher_rows.size,
      enrollments: @teacher_rows.sum { |r| r[:enrollment_count] },
      tuition: @teacher_rows.sum { |r| r[:tuition_total] },
      payment: @teacher_rows.sum { |r| r[:payment_amount] }
    }
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

    enrollments = Enrollment.joins(enrollment_sections: :section)
                            .where(sections: { teacher_id: @teacher.id })
                            .where(created_at: month.beginning_of_month..month.end_of_month)
                            .distinct
    total_tuition = enrollments.sum(&:total_tuition_fee)
    payment_amount = (total_tuition * 0.425).to_i

    payment = TeacherPayment.find_or_initialize_by(
      teacher_id: @teacher.id,
      period_start: month.beginning_of_month,
      period_end: month.end_of_month
    )

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
