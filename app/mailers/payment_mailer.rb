class PaymentMailer < ApplicationMailer
  MESES = %w[ene feb mar abr may jun jul ago sep oct nov dic].freeze

  # Confirmación de pago + datos de la matrícula.
  # Se envía cuando la transacción de Transbank queda autorizada y ya existen
  # el Payment y la inscripción (ver TransbankController#callback).
  def confirmation(payment)
    @payment    = payment
    @enrollment = payment.enrollment
    @student    = @enrollment.student
    @user       = @student.user

    @sections   = @enrollment.sections.includes(:course).to_a
    @courses    = @sections.map(&:course).uniq

    # Buy order de Transbank (identificador de la orden de compra). Se busca la
    # transacción cuyo código de autorización coincide con el del pago; si no
    # calza, cae a la última transacción de la matrícula.
    txns = @enrollment.transbank_transactions.order(:created_at)
    @buy_order = txns.where(authorization_code: @payment.reference_number).last&.buy_order
    @buy_order ||= txns.last&.buy_order

    # Clases regulares del plan (las de recuperatorio se agendan aparte), cada una
    # con su día, horario y fecha juntos.
    @classes = @enrollment.enrollment_sections.regular.includes(:section).order(:date).map do |es|
      d = es.date
      {
        weekday:  es.section&.weekday,
        schedule: es.section&.formatted_schedule,
        date:     d,
        day:      d&.day,
        month:    (d ? MESES[d.month - 1] : nil)
      }
    end

    # Banner adjunto inline (CID): el correo queda autocontenido, sin depender
    # de que la imagen esté hosteada ni de la configuración de asset_host.
    attachments.inline["banner-email-gustarte.png"] =
      File.read(Rails.root.join("app/assets/images/banner-email-gustarte.png"))

    # Copia (oculta) a los administradores: reciben cada confirmación de pago
    # sin exponer sus correos al alumno.
    admin_emails = User.joins(:admin_user).distinct.pluck(:email)

    mail(
      to: @user.email,
      bcc: admin_emails,
      subject: "Confirmación de pago y matrícula — #{@courses.map(&:title).join(', ')}"
    )
  end
end
