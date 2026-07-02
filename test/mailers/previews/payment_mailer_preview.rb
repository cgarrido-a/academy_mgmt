# Preview en http://localhost:3000/rails/mailers/payment_mailer/confirmation
class PaymentMailerPreview < ActionMailer::Preview
  def confirmation
    payment = Payment.enrollment_fees.completed.last || Payment.last
    raise "No hay pagos para previsualizar" if payment.nil?

    PaymentMailer.confirmation(payment)
  end
end
