# Feed de reportes CSV para consumo externo (ej. Google Apps Script
# refrescando una planilla). No pasa por Devise: se protege con un token
# fijo en vez de sesión, porque quien llama no puede "loguearse".
class ReportsController < ApplicationController
  EXPORTERS = {
    'financial' => FinancialReportCsvExporter,
    'monthly' => MonthlyFinancialReportCsvExporter,
    'monthly_by_course' => MonthlyCourseFinancialReportCsvExporter
  }.freeze

  def show
    return head :unauthorized unless token_valid?

    csv_data = EXPORTERS.fetch(params[:key]).call
    send_data csv_data, filename: "#{params[:key]}.csv", type: 'text/csv; charset=utf-8', disposition: 'inline'
  end

  private

  def token_valid?
    expected = ENV['REPORTS_TOKEN']
    return false if expected.blank?

    ActiveSupport::SecurityUtils.secure_compare(expected, params[:token].to_s)
  rescue ArgumentError
    # secure_compare exige igual longitud; un token de otro largo no es válido.
    false
  end
end
