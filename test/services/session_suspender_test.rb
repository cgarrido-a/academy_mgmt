require "test_helper"

class SessionSuspenderTest < ActiveSupport::TestCase
  # NOTA: escrito sin BD local en esta sesión (toolchain rbenv/RVM + Postgres no
  # disponibles). Correr con `bin/rails test test/services/session_suspender_test.rb`.
  setup do
    teacher_user = User.create!(email: "profe@test.cl", password: "password123", name: "Profe Test")
    @teacher = Teacher.create!(user: teacher_user, profession: "Artista")
    @admin_user = User.create!(email: "admin@test.cl", password: "password123", name: "Admin Test")
    @course = Course.create!(title: "Óleo Test", description: "curso de prueba")
    @section = Section.create!(
      course: @course, teacher: @teacher, places: 8, weekday: "Miércoles",
      schedule: [{ "start_time" => "10:00", "end_time" => "12:00" }]
    )
    @method = PaymentMethod.create!(payment_method: "Efectivo")
    @plan = WeeklyPlan.create!(plan: "Mensual", description: "4 clases", number_of_classes: 4,
                               weekly_classes: 1, course: @course)
    # 4 miércoles: 1, 8, 15, 22 de julio 2026
    @dates = (0..3).map { |i| Date.new(2026, 7, 1) + (i * 7) }
  end

  def enroll(name)
    u = User.create!(email: "#{name}@test.cl", password: "password123", name: name)
    student = Student.create!(user: u)
    enr = Enrollment.create!(student: student, weekly_plan: @plan, payment_method: @method,
                             enrollment_amount: 0, total_tuition_fee: 40_000)
    @dates.each { |d| EnrollmentSection.create!(enrollment: enr, section: @section, date: d, kind: "regular") }
    enr
  end

  test "corre la clase suspendida al final del plan de cada alumno y registra la suspensión" do
    e1 = enroll("ana")
    e2 = enroll("beto")
    suspended_date = @dates[1] # 8 jul

    result = SessionSuspender.new(section: @section, date: suspended_date,
                                  reason: "paro", admin_user: @admin_user).call

    assert_equal 2, result.moved.size
    assert_equal 2, result.suspension.affected_count
    assert_equal suspended_date, result.suspension.original_date
    assert_equal @course.id, result.suspension.section.course_id

    # Nadie quedó con clase en la fecha suspendida
    assert_equal 0, @section.enrollment_sections.where(date: suspended_date).count

    # Cada alumno tiene su clase corrida al 29 jul (última era 22 jul → +7), como regular y sin asistencia
    expected = @dates.last + 7.days
    [e1, e2].each do |enr|
      moved = enr.enrollment_sections.find_by(date: expected)
      assert moved, "#{enr.student.user.name} debería tener su clase corrida al #{expected}"
      assert_equal "regular", moved.kind
      assert_equal result.suspension.id, moved.class_suspension_id
      assert_nil moved.attended, "la clase corrida no debe contar como falta"
      assert_equal 4, enr.enrollment_sections.regular.count, "sigue teniendo 4 clases (N pagadas = N entregadas)"
    end
  end

  test "no mueve clases con asistencia ya marcada" do
    enr = enroll("caro")
    suspended_date = @dates[1]
    es = enr.enrollment_sections.find_by(date: suspended_date)
    es.update!(attended: true)

    result = SessionSuspender.new(section: @section, date: suspended_date,
                                  reason: "x", admin_user: @admin_user).call

    assert_equal 0, result.moved.size
    assert_equal 1, result.skipped.size
    assert_equal suspended_date, es.reload.date
  end

  test "si la fecha de fin+1 no tiene cupo, cae en la siguiente semana con cupo" do
    # Llenar la sección el 29 jul (fin+7) con 8 clases de otros enrollments para forzar el +14
    full_date = @dates.last + 7.days
    8.times do |i|
      u = User.create!(email: "relleno#{i}@test.cl", password: "password123", name: "Relleno #{i}")
      st = Student.create!(user: u)
      en = Enrollment.create!(student: st, weekly_plan: @plan, payment_method: @method,
                              enrollment_amount: 0, total_tuition_fee: 40_000)
      EnrollmentSection.create!(enrollment: en, section: @section, date: full_date, kind: "regular")
    end

    enr = enroll("dani")
    result = SessionSuspender.new(section: @section, date: @dates[1],
                                  reason: "y", admin_user: @admin_user).call

    moved = result.moved.first
    assert_equal full_date + 7.days, moved.date, "debe saltar a fin+14 porque fin+7 estaba lleno"
  end
end
