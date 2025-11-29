class EnrollmentCreator
  attr_reader :errors, :enrollment

  def initialize(params)
    @name = params[:name]
    @email = params[:email]
    @phone = params[:phone]
    @start_date = params[:start_date]
    @section_ids = params[:section_ids] || [params[:section_id]].compact
    @section_dates = params[:section_dates] || {}
    @payment_plan_id = params[:payment_plan_id]
    @payment_method_id = params[:payment_method_id]
    @enrollment_amount = params[:enrollment_amount]
    @total_tuition_fee = params[:total_tuition_fee]
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
      # Create new user with temporary password and phone
      @user = User.create!(
        name: @name,
        email: @email,
        phone: @phone,
        password: generate_temporary_password
      )
    else
      # Update existing user's phone if provided
      @user.update!(phone: @phone) if @phone.present?
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
      total_tuition_fee: @total_tuition_fee,
      payment_date: Date.today
    )
  end

  def create_enrollment_sections
    # Get number of classes from payment plan
    payment_plan = PaymentPlan.find(@payment_plan_id)
    number_of_classes = payment_plan.number_of_classes

    # Use start_date if provided, otherwise check section_dates hash for backwards compatibility
    start_date_to_use = @start_date.presence || @section_dates.values.first

    if start_date_to_use.blank?
      raise "Debe especificar una fecha de inicio (start_date)"
    end

    # Parse date if it's a string
    start_date_to_use = Date.parse(start_date_to_use) if start_date_to_use.is_a?(String)

    @section_ids.each do |section_id|
      section = Section.find(section_id)

      # Generate dates for all classes starting from start_date
      class_dates = generate_class_dates(section, start_date_to_use, number_of_classes)

      # Create an enrollment_section for each class date
      class_dates.each do |date|
        EnrollmentSection.create!(
          enrollment: @enrollment,
          section_id: section_id,
          date: date
        )
      end
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
      amount: @total_tuition_fee,
      payment_date: Date.today,
      payment_method_id: @payment_method_id,
      status: 'completed'
    )
  end

  def generate_temporary_password
    # Generate a random temporary password
    SecureRandom.hex(8)
  end

  def generate_class_dates(section, start_date, number_of_classes)
    # Map Spanish weekday names to Ruby's wday (0 = Sunday, 1 = Monday, etc.)
    weekday_map = {
      'Domingo' => 0,
      'Lunes' => 1,
      'Martes' => 2,
      'Miércoles' => 3,
      'Jueves' => 4,
      'Viernes' => 5,
      'Sábado' => 6
    }

    target_wday = weekday_map[section.weekday]
    dates = []
    current_date = start_date

    # Ensure start_date matches the section's weekday
    unless current_date.wday == target_wday
      raise "La fecha de inicio #{start_date.strftime('%d/%m/%Y')} no es un #{section.weekday}"
    end

    # Generate the specified number of class dates with available spots
    max_attempts = number_of_classes * 10  # Evitar bucle infinito
    attempts = 0

    while dates.length < number_of_classes && attempts < max_attempts
      # Check if this date has available places
      if section.has_available_places_for_date?(current_date)
        dates << current_date
      end
      # If no spots available, skip to next week

      current_date += 7.days  # Next week, same day
      attempts += 1
    end

    if dates.length < number_of_classes
      raise "No se pudieron encontrar #{number_of_classes} fechas con cupos disponibles. Solo se encontraron #{dates.length} fechas."
    end

    dates
  end
end
