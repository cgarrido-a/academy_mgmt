class AdminAlertMailer < ApplicationMailer
  # Aviso interno cuando una transacción de Transbank necesita mirada humana.
  #
  # Los dos casos que lo disparan (ver TransbankController#callback):
  # 1. Transbank cobró y la matrícula no se pudo crear (status authorized_error).
  # 2. La matrícula se creó pero hubo que completarle fechas que el front no envió.
  #
  # Sin este aviso un cobro sin matrícula queda invisible hasta que la alumna reclama,
  # que es exactamente lo que pasó el 3-ago-2026 con la transacción 140 ($144.000).
  def transbank_incident(transbank_transaction, message)
    @transaction = transbank_transaction
    @message = message
    @enrollment = @transaction.enrollment
    @student_data = student_data_from(@transaction)
    @admin_url = admin_transaction_url(@transaction)

    destinatarios = User.admin_notification_emails
    if destinatarios.empty?
      Rails.logger.error "No hay correos de admin para avisar del incidente de la tx #{@transaction.id}"
      return NullMail.new
    end

    mail(
      to: destinatarios,
      subject: "[Gustarte] Revisar pago #{@transaction.buy_order} — $#{@transaction.amount.to_i}"
    )
  end

  private

  # Datos de la alumna: si la matrícula no se creó, sólo existen en enrollment_data.
  def student_data_from(transaction)
    if transaction.enrollment.present?
      user = transaction.enrollment.student&.user
      return { name: user&.name, email: user&.email, phone: user&.phone }
    end

    data = transaction.enrollment_data
    data = (JSON.parse(data) rescue {}) if data.is_a?(String)
    data = data.with_indifferent_access if data.respond_to?(:with_indifferent_access)
    first = Array(data[:enrollments]).first || data
    { name: first[:name], email: first[:email], phone: first[:phone] }
  end

  def admin_transaction_url(transaction)
    host = ENV['BACKEND_URL'].presence
    host ? "#{host.chomp('/')}/admin/transbank_transactions/#{transaction.id}" : nil
  end

  # Para no reventar si no hay a quién avisarle (deliver_later sobre esto no hace nada).
  class NullMail
    def deliver_later(*) = nil
    def deliver_now(*) = nil
  end
end
