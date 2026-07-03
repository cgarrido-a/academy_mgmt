# Tareas para probar el envío de correo por SMTP (Resend) sin depender de un deploy.
#
# Uso (setea las ENV en el shell y corre la tarea; NO commitees la API key):
#
#   SMTP_ADDRESS=smtp.resend.com SMTP_USERNAME=resend \
#   SMTP_PASSWORD=re_tu_api_key MAIL_FROM=no-reply@gustarte.cl \
#   bin/rails "mail:test[tu_correo@ejemplo.com]"
#
# Envía un correo real usando la config SMTP de producción (Resend), aunque
# estés en desarrollo. Sirve para validar dominio verificado + API key + entregabilidad.
namespace :mail do
  desc "Envía un correo de prueba real vía SMTP (Resend). Uso: mail:test[destino@ejemplo.com]"
  task :test, [:to] => :environment do |_t, args|
    to = args[:to] || ENV["MAIL_TEST_TO"]
    abort "Falta destinatario. Uso: bin/rails 'mail:test[destino@ejemplo.com]'" if to.blank?

    missing = %w[SMTP_ADDRESS SMTP_USERNAME SMTP_PASSWORD].reject { |k| ENV[k].present? }
    abort "Faltan variables de entorno: #{missing.join(', ')}" if missing.any?

    settings = {
      address:              ENV["SMTP_ADDRESS"],
      port:                 ENV.fetch("SMTP_PORT", 587).to_i,
      domain:               ENV["SMTP_DOMAIN"],
      user_name:            ENV["SMTP_USERNAME"],
      password:             ENV["SMTP_PASSWORD"],
      authentication:       ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
      enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS_AUTO", "true") == "true"
    }
    from = ENV.fetch("MAIL_FROM", "no-reply@gustarte.cl")

    puts "Enviando correo de prueba vía #{settings[:address]}:#{settings[:port]}"
    puts "  De:    #{from}"
    puts "  Para:  #{to}"

    mail = ActionMailer::Base.mail(
      to: to,
      from: from,
      subject: "Prueba de envío — #{Time.current.strftime('%Y-%m-%d %H:%M')}",
      body: "Si recibiste este correo, el envío por SMTP (Resend) funciona correctamente."
    )
    mail.delivery_method(:smtp, settings)
    mail.deliver!

    puts "✔ Correo enviado. Revisa la bandeja (y spam) de #{to} y el dashboard de Resend."
  rescue StandardError => e
    abort "✖ Error al enviar: #{e.class}: #{e.message}"
  end

  desc "Envía el PaymentMailer#confirmation real del último pago. Uso: mail:test_confirmation[destino@ejemplo.com]"
  task :test_confirmation, [:to] => :environment do |_t, args|
    missing = %w[SMTP_ADDRESS SMTP_USERNAME SMTP_PASSWORD].reject { |k| ENV[k].present? }
    abort "Faltan variables de entorno: #{missing.join(', ')}" if missing.any?

    payment = Payment.respond_to?(:enrollment_fees) ? Payment.enrollment_fees.completed.last : nil
    payment ||= Payment.last
    abort "No hay pagos en la base para previsualizar." if payment.nil?

    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.smtp_settings = {
      address:              ENV["SMTP_ADDRESS"],
      port:                 ENV.fetch("SMTP_PORT", 587).to_i,
      domain:               ENV["SMTP_DOMAIN"],
      user_name:            ENV["SMTP_USERNAME"],
      password:             ENV["SMTP_PASSWORD"],
      authentication:       ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
      enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS_AUTO", "true") == "true"
    }

    mail = PaymentMailer.confirmation(payment)
    mail.to = [args[:to]] if args[:to].present?
    mail.deliver!

    puts "✔ Confirmación de pago ##{payment.id} enviada a #{mail.to.join(', ')}."
  rescue StandardError => e
    abort "✖ Error al enviar: #{e.class}: #{e.message}"
  end
end
