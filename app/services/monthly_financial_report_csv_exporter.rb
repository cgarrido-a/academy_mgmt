require 'csv'

# Resumen mensual de ingresos: agrupa Payment.completed por mes de payment_date
# y desglosa por método de pago. Es el complemento agregado de
# FinancialReportCsvExporter, que lista cada pago por separado.
class MonthlyFinancialReportCsvExporter
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
        ] + method_names.map { |name| data[:by_method][name] }
      end
    end
  end

  private

  def payments
    @payments ||= Payment.completed.includes(:payment_method).order(payment_date: :desc)
  end

  def method_names
    @method_names ||= payments.map { |p| p.payment_method.payment_method }.uniq.sort
  end

  def monthly_totals
    totals = {}

    payments.each do |payment|
      month = payment.payment_date.beginning_of_month
      entry = (totals[month] ||= { total: 0, count: 0, by_method: Hash.new(0) })
      entry[:total] += payment.amount
      entry[:count] += 1
      entry[:by_method][payment.payment_method.payment_method] += payment.amount
    end

    totals.sort_by { |month, _| month }.reverse
  end

  def headers
    ['Mes', 'Total Cobrado', 'N° de Pagos'] + method_names
  end
end
