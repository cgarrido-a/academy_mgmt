require 'csv'

# Resumen mensual de ingresos desglosado por curso: agrupa Payment.completed
# por mes de payment_date y por el curso de la matrícula asociada. Complementa
# a MonthlyFinancialReportCsvExporter (que desglosa por método de pago) y a
# FinancialReportCsvExporter (que lista cada pago por separado).
class MonthlyCourseFinancialReportCsvExporter
  def self.call
    new.call
  end

  def call
    CSV.generate(headers: true, col_sep: ',', encoding: 'UTF-8') do |csv|
      csv << headers

      monthly_totals.each do |month, data|
        csv << [
          I18n.l(month, format: '%B %Y').capitalize,
          data[:total],
          data[:count]
        ] + course_names.map { |name| data[:by_course][name] }
      end
    end
  end

  private

  def payments
    @payments ||= Payment.completed
                          .includes(enrollment: [{ weekly_plan: :course }, { sections: :course }])
                          .order(payment_date: :desc)
  end

  def course_names
    @course_names ||= payments.map { |p| course_label(p) }.uniq.sort
  end

  def monthly_totals
    totals = {}

    payments.each do |payment|
      month = payment.payment_date.beginning_of_month
      entry = (totals[month] ||= { total: 0, count: 0, by_course: Hash.new(0) })
      entry[:total] += payment.amount
      entry[:count] += 1
      entry[:by_course][course_label(payment)] += payment.amount
    end

    totals.sort_by { |month, _| month }.reverse
  end

  # El plan semanal es la fuente de verdad del curso de una matrícula, pero en
  # datos viejos puede no tener course_id asignado todavía (ver
  # replicate_to_courses); en ese caso se cae a los cursos de sus secciones.
  def course_label(payment)
    enrollment = payment.enrollment
    course = enrollment.weekly_plan&.course
    return course.title if course

    titles = enrollment.sections.map { |s| s.course.title }.uniq
    titles.any? ? titles.join(', ') : 'Sin curso'
  end

  def headers
    ['Mes', 'Total Cobrado', 'N° de Pagos'] + course_names
  end
end
