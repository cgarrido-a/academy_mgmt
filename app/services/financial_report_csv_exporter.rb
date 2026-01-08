require 'csv'

class FinancialReportCsvExporter
  def self.call
    new.call
  end

  def call
    CSV.generate(headers: true, col_sep: ',', encoding: 'UTF-8') do |csv|
      # Headers
      csv << headers

      # Data rows
      Enrollment.includes(
        { student: :user },
        :weekly_plan,
        :payment_method,
        { payments: :payment_method },
        { sections: [:course, { teacher: :user }] }
      ).order(created_at: :desc).find_each do |enrollment|
        student = enrollment.student
        user = student.user

        # Get all courses enrolled
        courses = enrollment.sections.map { |s| s.course.title }.uniq.join(', ')

        # Get all sections info
        sections_info = enrollment.sections.map do |s|
          "#{s.course.title} - #{s.weekday} #{s.formatted_schedule}"
        end.join(' | ')

        # Get all payments info
        enrollment.payments.each do |payment|
          csv << [
            # Student info
            user.name,
            user.email,
            user.phone,

            # Enrollment info
            enrollment.id,
            enrollment.created_at.strftime('%d/%m/%Y'),
            enrollment.weekly_plan.plan,
            enrollment.weekly_plan.number_of_classes,
            enrollment.weekly_plan.weekly_classes,
            courses,
            sections_info,

            # Financial info - Enrollment
            enrollment.enrollment_amount,
            enrollment.total_tuition_fee,
            enrollment.enrollment_amount + enrollment.total_tuition_fee,
            enrollment.total_paid,
            (enrollment.enrollment_amount + enrollment.total_tuition_fee) - enrollment.total_paid,

            # Payment info
            payment.id,
            payment.payment_type,
            payment.amount,
            payment.payment_date.strftime('%d/%m/%Y'),
            payment.payment_method.payment_method,
            payment.reference_number,
            payment.status,
            payment.notes
          ]
        end

        # If no payments, still show enrollment info
        if enrollment.payments.empty?
          csv << [
            # Student info
            user.name,
            user.email,
            user.phone,

            # Enrollment info
            enrollment.id,
            enrollment.created_at.strftime('%d/%m/%Y'),
            enrollment.weekly_plan.plan,
            enrollment.weekly_plan.number_of_classes,
            enrollment.weekly_plan.weekly_classes,
            courses,
            sections_info,

            # Financial info - Enrollment
            enrollment.enrollment_amount,
            enrollment.total_tuition_fee,
            enrollment.enrollment_amount + enrollment.total_tuition_fee,
            enrollment.total_paid,
            (enrollment.enrollment_amount + enrollment.total_tuition_fee) - enrollment.total_paid,

            # Payment info (empty)
            nil, nil, nil, nil, nil, nil, nil, nil
          ]
        end
      end
    end
  end

  private

  def headers
    [
      # Student info
      'Nombre Estudiante',
      'Email',
      'Teléfono',

      # Enrollment info
      'ID Matrícula',
      'Fecha Matrícula',
      'Plan Semanal',
      'Número de Clases',
      'Clases por Semana',
      'Cursos',
      'Secciones',

      # Financial info - Enrollment totals
      'Monto Matrícula',
      'Colegiatura Total',
      'Total a Pagar',
      'Total Pagado',
      'Saldo Pendiente',

      # Payment details
      'ID Pago',
      'Tipo de Pago',
      'Monto Pago',
      'Fecha de Pago',
      'Método de Pago',
      'Número de Referencia',
      'Estado Pago',
      'Notas'
    ]
  end
end
