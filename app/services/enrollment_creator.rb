class EnrollmentCreator
  attr_reader :errors, :enrollment

  def initialize(params)
    @name = params[:name]
    @email = params[:email]
    @section_id = params[:section_id]
    @payment_plan_id = params[:payment_plan_id]
    @payment_method_id = params[:payment_method_id]
    @enrollment_amount = params[:enrollment_amount]
    @instalments_number = params[:instalments_number]&.to_i || 1
    @errors = []
    @enrollment = nil
  end

  def call
    ActiveRecord::Base.transaction do
      find_or_create_user_and_student
      create_enrollment
      create_tuition_fee_and_installments
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
      section_id: @section_id,
      payment_plan_id: @payment_plan_id,
      payment_method_id: @payment_method_id,
      enrollment_amount: @enrollment_amount,
      payment_date: Date.today
    )
  end

  def create_tuition_fee_and_installments
    # Create tuition fee
    tuition_fee = TuitionFee.create!(
      enrollment: @enrollment,
      payment_method_id: @payment_method_id,
      total_tuition_fee: @enrollment_amount,
      instalments_number: @instalments_number,
      billing_period: generate_billing_period
    )

    # Generate installments
    generate_installments(tuition_fee, @instalments_number)
  end

  def generate_installments(tuition_fee, number_of_installments)
    amount_per_installment = (@enrollment_amount.to_f / number_of_installments).round

    number_of_installments.times do |i|
      # Adjust last installment to account for rounding differences
      installment_amount = if i == number_of_installments - 1
        @enrollment_amount - (amount_per_installment * (number_of_installments - 1))
      else
        amount_per_installment
      end

      Installment.create!(
        tuition_fee: tuition_fee,
        amount: installment_amount,
        due_date: calculate_due_date(i),
        status: 'pending'
      )
    end
  end

  def calculate_due_date(installment_index)
    # Due date is monthly starting from today
    Date.today + (installment_index + 1).months
  end

  def generate_billing_period
    section = Section.find(@section_id)
    "#{section.start_date.strftime('%Y-%m')} - #{section.end_date.strftime('%Y-%m')}"
  end

  def generate_temporary_password
    # Generate a random temporary password
    SecureRandom.hex(8)
  end
end
