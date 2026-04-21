class Admin::TeacherPaymentsController < Admin::ApplicationController
  PAYMENT_PERCENTAGE = 0.425

  def index
    @available_months = EnrollmentSection
                          .select("DISTINCT DATE_TRUNC('month', date) AS month_date")
                          .map { |r| r.month_date.to_date }
                          .sort
                          .reverse

    if params[:month].present?
      @selected_month = Date.parse(params[:month])
    else
      @selected_month = @available_months.first || Date.current.beginning_of_month
    end

    @selected_status = params[:status]

    month_index = @available_months.index(@selected_month.beginning_of_month)
    if month_index
      @nav_next = month_index > 0 ? @available_months[month_index - 1] : nil
      @nav_prev = month_index < @available_months.size - 1 ? @available_months[month_index + 1] : nil
    else
      @nav_prev = @selected_month.prev_month
      @nav_next = @selected_month.next_month
    end

    @teacher_rows = build_teacher_rows(@selected_month)
    @teacher_rows = @teacher_rows.select { |r| r[:status] == @selected_status } if @selected_status.present?
    @teacher_rows.sort_by! { |r| r[:name] }

    @summary = {
      teachers: @teacher_rows.size,
      attended_classes: @teacher_rows.sum { |r| r[:attended_count] },
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

    @selected_course = params[:course_id].to_i if params[:course_id].present?

    attended = attended_sections_scope(@teacher.id, @month)
    attended = attended.where(sections: { course_id: @selected_course }) if @selected_course
    attended = attended.includes(enrollment: { student: :user, weekly_plan: [] }, section: :course).to_a

    session_counts = session_counts_for(attended)

    @enrollment_rows = attended.group_by(&:enrollment).map do |enrollment, sections|
      total = session_counts[enrollment.id].to_i
      price_per_class = total.zero? ? 0.0 : enrollment.total_tuition_fee.to_f / total
      {
        enrollment: enrollment,
        attended_count: sections.size,
        total_sessions: total,
        price_per_class: price_per_class,
        attended_value: price_per_class * sections.size,
        courses: sections.map { |s| s.section.course }.uniq
      }
    end

    @enrollment_rows.sort_by! { |r| r[:enrollment].student.user.name }

    tuition_raw = @enrollment_rows.sum { |r| r[:attended_value] }
    @attended_count = @enrollment_rows.sum { |r| r[:attended_count] }
    @total_tuition = tuition_raw.round
    @payment_amount = (tuition_raw * PAYMENT_PERCENTAGE).round
  end

  def toggle_status
    @teacher = Teacher.find(params[:id])
    month = Date.parse(params[:month])
    new_status = params[:new_status]

    payment_amount = compute_teacher_payment(@teacher.id, month)

    payment = TeacherPayment.find_or_initialize_by(
      teacher_id: @teacher.id,
      period_start: month.beginning_of_month,
      period_end: month.end_of_month
    )

    payment.amount = payment_amount
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

  private

  def attended_sections_scope(teacher_id, month)
    EnrollmentSection
      .where(attended: true, date: month.beginning_of_month..month.end_of_month)
      .joins(:section)
      .where(sections: { teacher_id: teacher_id })
  end

  def session_counts_for(attended_sections)
    enrollment_ids = attended_sections.map(&:enrollment_id).uniq
    EnrollmentSection.where(enrollment_id: enrollment_ids).group(:enrollment_id).count
  end

  def build_teacher_rows(month)
    attended = EnrollmentSection
                 .where(attended: true, date: month.beginning_of_month..month.end_of_month)
                 .includes(:enrollment, section: { teacher: :user })

    session_counts = session_counts_for(attended)

    rows = {}
    attended.each do |es|
      teacher = es.section.teacher
      count = session_counts[es.enrollment_id].to_i
      next if count.zero?

      price_per_class = es.enrollment.total_tuition_fee.to_f / count

      row = rows[teacher.id] ||= {
        teacher: teacher,
        name: teacher.user.name,
        month: month.beginning_of_month,
        attended_count: 0,
        tuition_raw: 0.0
      }
      row[:attended_count] += 1
      row[:tuition_raw] += price_per_class
    end

    rows.values.map do |r|
      payment = TeacherPayment.find_by(
        teacher_id: r[:teacher].id,
        period_start: r[:month].beginning_of_month,
        period_end: r[:month].end_of_month
      )
      r[:status] = payment&.status || 'pending'
      r[:tuition_total] = r[:tuition_raw].round
      r[:payment_amount] = (r[:tuition_raw] * PAYMENT_PERCENTAGE).round
      r
    end
  end

  def compute_teacher_payment(teacher_id, month)
    attended = attended_sections_scope(teacher_id, month).includes(:enrollment).to_a
    session_counts = session_counts_for(attended)

    raw = attended.sum do |es|
      count = session_counts[es.enrollment_id].to_i
      count.zero? ? 0 : es.enrollment.total_tuition_fee.to_f / count
    end

    (raw * PAYMENT_PERCENTAGE).round
  end
end
