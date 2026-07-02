class PaymentMailer < ApplicationMailer
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
    # Fechas de las clases regulares del plan (las de recuperatorio se agendan aparte).
    @class_dates = @enrollment.enrollment_sections.regular.order(:date).pluck(:date)

    mail(
      to: @user.email,
      subject: "Confirmación de pago y matrícula — #{@courses.map(&:title).join(', ')}"
    )
  end
end
