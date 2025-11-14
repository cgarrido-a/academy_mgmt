class MigrateExistingPaymentData < ActiveRecord::Migration[7.1]
  def up
    # Migrate enrollment payment_date to payments table
    Enrollment.where.not(payment_date: nil).find_each do |enrollment|
      Payment.create!(
        enrollment_id: enrollment.id,
        payment_type: 'enrollment_fee',
        installment_id: nil,
        amount: enrollment.enrollment_amount,
        payment_date: enrollment.payment_date,
        payment_method_id: enrollment.payment_method_id,
        status: 'completed'
      )
    end

    # Migrate installment payments to payments table
    Installment.where(status: 'paid').where.not(payment_date: nil).find_each do |installment|
      Payment.create!(
        enrollment_id: installment.tuition_fee.enrollment_id,
        payment_type: 'installment',
        installment_id: installment.id,
        amount: installment.amount,
        payment_date: installment.payment_date,
        payment_method_id: installment.tuition_fee.payment_method_id,
        status: 'completed'
      )
    end
  end

  def down
    # Optionally restore data back to original tables
    Payment.where(payment_type: 'enrollment_fee').find_each do |payment|
      enrollment = Enrollment.find(payment.enrollment_id)
      enrollment.update_columns(payment_date: payment.payment_date)
    end

    Payment.where(payment_type: 'installment').find_each do |payment|
      installment = Installment.find(payment.installment_id)
      installment.update_columns(
        payment_date: payment.payment_date,
        status: 'paid'
      )
    end

    Payment.delete_all
  end
end
