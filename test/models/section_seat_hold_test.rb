require "test_helper"

class SectionSeatHoldTest < ActiveSupport::TestCase
  setup do
    BusinessRule.delete_all
    BusinessRule.create!(max_days_ahead_for_start: 30, seat_hold_days: 7)

    teacher_user = User.create!(email: "profe@test.cl", password: "password123", name: "Profe Test")
    teacher = Teacher.create!(user: teacher_user, profession: "Artista")
    @course = Course.create!(title: "Óleo Test", description: "curso de prueba")
    @section = Section.create!(
      course: @course, teacher: teacher, places: 1, weekday: "Miércoles",
      schedule: [{ "start_time" => "10:00", "end_time" => "12:00" }]
    )
    @method = PaymentMethod.create!(payment_method: "Efectivo")
    @plan = WeeklyPlan.create!(plan: "Mensual", description: "4 clases", number_of_classes: 4,
                               weekly_classes: 1, course: @course)
    @wednesday = Date.new(2026, 10, 14)
  end

  def enroll(name, dates)
    u = User.create!(email: "#{name}@test.cl", password: "password123", name: name)
    student = Student.create!(user: u)
    enr = Enrollment.create!(student: student, weekly_plan: @plan, payment_method: @method,
                             enrollment_amount: 0, total_tuition_fee: 40_000)
    dates.each { |d| EnrollmentSection.create!(enrollment: enr, section: @section, date: d, kind: "regular") }
    enr
  end

  test "con el plan vigente, el cupo queda reservado para las fechas siguientes" do
    travel_to @wednesday do
      ana = enroll("ana", [@wednesday, @wednesday + 7])

      assert_equal 0, @section.available_places_for_date(@wednesday + 14)
      assert_equal 1, @section.available_places_for_date(@wednesday + 14, except_student_id: ana.student_id)
    end
  end

  test "la reserva dura hasta seat_hold_days después de la última clase" do
    last = @wednesday
    enroll("ana", [last - 7, last])

    travel_to(last + 7) { assert_equal 0, @section.available_places_for_date(last + 7) }
    travel_to(last + 8) { assert_equal 1, @section.available_places_for_date(last + 14) }
  end

  test "otra alumna no puede tomar el cupo reservado" do
    travel_to @wednesday do
      enroll("ana", [@wednesday])
      beto = Student.create!(user: User.create!(email: "beto@test.cl", password: "password123", name: "Beto"))
      enr = Enrollment.create!(student: beto, weekly_plan: @plan, payment_method: @method,
                               enrollment_amount: 0, total_tuition_fee: 40_000)

      es = EnrollmentSection.new(enrollment: enr, section: @section, date: @wednesday + 7, kind: "regular")
      assert_not es.valid?
      assert_match "no tiene cupos", es.errors.full_messages.join
    end
  end

  test "la misma alumna puede renovar en su horario" do
    travel_to @wednesday + 3 do
      ana = enroll("ana", [@wednesday])
      renewal = Enrollment.create!(student: ana.student, weekly_plan: @plan, payment_method: @method,
                                   enrollment_amount: 0, total_tuition_fee: 40_000)

      assert EnrollmentSection.new(enrollment: renewal, section: @section, date: @wednesday + 7, kind: "regular").valid?
    end
  end

  test "marcar asistencia no vuelve a validar el cupo" do
    travel_to @wednesday do
      ana = enroll("ana", [@wednesday])
      es = ana.enrollment_sections.first
      assert es.update(attended: true)
    end
  end

  test "con seat_hold_days en 0 no hay reserva" do
    BusinessRule.current.update!(seat_hold_days: 0)
    travel_to @wednesday do
      enroll("ana", [@wednesday])
      assert_equal 1, @section.available_places_for_date(@wednesday + 7)
    end
  end

  test "max_start_date respeta el plazo y 0 lo desactiva" do
    rule = BusinessRule.current
    assert_equal Date.new(2026, 11, 13), rule.max_start_date(Date.new(2026, 10, 14))
    rule.max_days_ahead_for_start = 0
    assert_nil rule.max_start_date
  end
end
