require "test_helper"

# Cubre el incidente del 3-ago-2026: el front mandó 13 fechas para un plan de 16
# clases, el back cobró por 16 y después no pudo crear la matrícula.
#
# Reglas que se verifican acá:
# - la cantidad de verdad es la del plan (número de clases × meses), no las fechas enviadas
# - ANTES de cobrar (allow_autocomplete: false) un payload corto se rechaza
# - DESPUÉS de cobrar (allow_autocomplete: true) las fechas que falten se completan
# - más fechas que el plan se rechaza siempre
# - validate_batch no deja nada escrito
class EnrollmentCreatorTest < ActiveSupport::TestCase
  # NOTA: mismo patrón que session_suspender_test.rb (datos creados a mano, sin fixtures).
  setup do
    teacher_user = User.create!(email: "profe.creator@test.cl", password: "password123", name: "Profe Creator")
    @teacher = Teacher.create!(user: teacher_user, profession: "Artista")
    @course = Course.create!(title: "Óleo Creator", description: "curso de prueba")
    # Sección de sábado, como la del incidente
    @section = Section.create!(
      course: @course, teacher: @teacher, places: 8, weekday: "Sábado",
      schedule: [{ "start_time" => "12:30", "end_time" => "14:30" }]
    )
    @plan = WeeklyPlan.create!(plan: "Plan mensual", description: "4 clases mensuales",
                               number_of_classes: 4, weekly_classes: 1, price: 40_000,
                               saturday_price: 45_000, course: @course)
    @cuatro_meses = PaymentPeriod.create!(months: 4, discount_percentage: 20,
                                          description: "4 meses")
    # El flujo de Transbank manda payment_method_id nil y el creator cae en "Webpay".
    @webpay = PaymentMethod.create!(payment_method: "Webpay")
    # Descuento por cantidad de clases: 16 clases = 20% (igual que en producción).
    ClassDiscount.create!(number_of_classes: 4, discount_percentage: 0)
    ClassDiscount.create!(number_of_classes: 16, discount_percentage: 20)

    # 16 sábados desde un sábado futuro (16 = 4 clases × 4 meses)
    primer_sabado = Date.current.next_occurring(:saturday) + 7
    @dieciseis_fechas = (0..15).map { |i| (primer_sabado + (i * 7)).to_s }
  end

  def params(dates, extra = {})
    {
      name: "Ximena Test",
      email: "ximena.test@example.cl",
      phone: "985624216",
      start_date: dates.first,
      section_ids: [@section.id],
      section_dates: { @section.id.to_s => dates },
      weekly_plan_id: @plan.id,
      payment_method_id: nil,
      payment_period_id: @cuatro_meses.id
    }.merge(extra)
  end

  test "crea la matrícula cuando llegan exactamente las fechas del plan" do
    creator = EnrollmentCreator.new(params(@dieciseis_fechas))

    assert creator.call, "esperaba que se creara: #{creator.errors.join(', ')}"
    assert_equal 16, creator.enrollment.enrollment_sections.count
    assert_empty creator.autocompleted_dates
    # El precio sale del plan, no de las fechas: 16 clases de sábado con 20% de descuento
    assert_equal 144_000, creator.enrollment.total_tuition_fee.to_i
  end

  test "rechaza un payload corto cuando no se permite autocompletar (antes de cobrar)" do
    creator = EnrollmentCreator.new(params(@dieciseis_fechas.first(13)))

    assert_not creator.call
    assert_match(/exactamente 16 fechas/, creator.errors.join(" "))
    assert_nil creator.enrollment&.reload rescue nil
  end

  test "completa las fechas que faltan cuando ya se cobró" do
    creator = EnrollmentCreator.new(params(@dieciseis_fechas.first(13)), allow_autocomplete: true)

    assert creator.call, "esperaba que se creara: #{creator.errors.join(', ')}"
    assert_equal 16, creator.enrollment.enrollment_sections.count
    assert_equal 3, creator.autocompleted_dates.size

    fechas = creator.enrollment.enrollment_sections.order(:date).pluck(:date)
    assert fechas.all?(&:saturday?), "todas las clases tienen que caer sábado"
    assert_equal fechas.uniq, fechas, "no puede repetir fechas"
    # Las completadas siguen después de la última enviada
    assert fechas.last > Date.parse(@dieciseis_fechas[12])
  end

  test "rechaza más fechas que las del plan incluso después de cobrar" do
    creator = EnrollmentCreator.new(params(@dieciseis_fechas + [(Date.parse(@dieciseis_fechas.last) + 7).to_s]),
                                    allow_autocomplete: true)

    assert_not creator.call
    assert_match(/17 fechas y el plan es de 16/, creator.errors.join(" "))
  end

  test "rechaza fechas que no caen en el día de la sección" do
    fechas = @dieciseis_fechas.dup
    fechas[5] = (Date.parse(fechas[5]) + 1).to_s # domingo

    creator = EnrollmentCreator.new(params(fechas))

    assert_not creator.call
    assert_match(/no es un Sábado/, creator.errors.join(" "))
  end

  test "validate_batch no escribe nada en la base" do
    conteos = lambda do
      { users: User.count, enrollments: Enrollment.count,
        clases: EnrollmentSection.count, payments: Payment.count }
    end

    antes = conteos.call
    errores = EnrollmentCreator.validate_batch([params(@dieciseis_fechas)])

    assert_empty errores
    assert_equal antes, conteos.call, "la validación no puede dejar rastro"
  end

  test "validate_batch devuelve el error de un payload que no se puede crear" do
    errores = EnrollmentCreator.validate_batch([params(@dieciseis_fechas.first(13))])

    assert_equal 1, errores.size
    assert_match(/exactamente 16 fechas/, errores.first)
  end

  test "validate_batch numera las inscripciones cuando el carrito trae varias" do
    errores = EnrollmentCreator.validate_batch([
      params(@dieciseis_fechas),
      params(@dieciseis_fechas.first(10), email: "otra.test@example.cl")
    ])

    assert_equal 1, errores.size
    assert_match(/Inscripción 2/, errores.first)
  end
end
