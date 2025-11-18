class EnrollmentCreator
  attr_reader :errors, :enrollment

  def initialize(params)
    @name = params[:name]
    @email = params[:email]
    @section_ids = params[:section_ids] || [params[:section_id]].compact
    @payment_plan_id = params[:payment_plan_id]
    @payment_method_id = params[:payment_method_id]
    @enrollment_amount = params[:enrollment_amount]
    @total_tuition_fee = params[:total_tuition_fee] || params[:enrollment_amount]
    @errors = []
    @enrollment = nil
  end

  def call
    ActiveRecord::Base.transaction do
      find_or_create_user_and_student
      create_enrollment
      create_enrollment_sections
      create_enrollment_fee_payment
    end

    @enrollment.present?
  rescue ActiveRecord::RecordInvalid => e
    @errors << e.message
    false
  rescue StandardError => e
    @errors << "Error creating enrollment: #{e.message}"
    false
  end

  private

  def find_or_create_user_and_student
    @user = User.find_by(email: @email)

    if @user.nil?
      # Create new user with temporary password
      @user = User.create!(
        name: @name,
        email: @email,
        password: generate_temporary_password
      )
    end

    # Find or create student
    @student = @user.student || @user.create_student!
  end

  def create_enrollment
    @enrollment = Enrollment.create!(
      student: @student,
      payment_plan_id: @payment_plan_id,
      payment_method_id: @payment_method_id,
      enrollment_amount: @enrollment_amount,
      payment_date: Date.today
    )
  end

  def create_enrollment_sections
    @section_ids.each do |section_id|
      EnrollmentSection.create!(
        enrollment: @enrollment,
        section_id: section_id
      )
    end
  end

  def create_enrollment_fee_payment
    # Only create payment record if payment method is NOT online payment (Transbank)
    # For Transbank, payment will be created after confirmation in the callback
    payment_method = PaymentMethod.find(@payment_method_id)

    # Skip payment creation for Transbank/Webpay/online card payments
    # Payment will be created after payment confirmation in Transbank callback
    return if payment_method.payment_method&.downcase&.include?('transbank') ||
              payment_method.payment_method&.downcase&.include?('webpay') ||
              payment_method.payment_method&.downcase&.include?('tarjeta') ||
              @payment_method_id == 1 # ID 1 is online card payment

    # For other payment methods (cash, transfer, etc), create payment immediately
    Payment.create!(
      enrollment: @enrollment,
      payment_type: 'enrollment_fee',
      amount: @enrollment_amount,
      payment_date: Date.today,
      payment_method_id: @payment_method_id,
      status: 'completed'
    )
  end
  def create_tuition_fee_and_installments
    # Create tuition fee
    tuition_fee = TuitionFee.create!(
      enrollment: @enrollment,
      payment_method_id: @payment_method_id,
      total_tuition_fee: @total_tuition_fee,
      billing_period: generate_billing_period
    )

  end

 

  def generate_billing_period
    # Use the first section to generate billing period
    section = Section.find(@section_ids.first)
    "#{section.start_date.strftime('%Y-%m')} - #{section.end_date.strftime('%Y-%m')}"
  end

  def generate_temporary_password
    # Generate a random temporary password
    SecureRandom.hex(8)
  end
end
