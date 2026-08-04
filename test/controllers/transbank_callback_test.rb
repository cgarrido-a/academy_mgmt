require "test_helper"
require "minitest/mock"

# El corazón del incidente del 3-ago-2026: qué pasa DESPUÉS de que Transbank cobra.
#
# Regla: si el pago está aprobado, la plata ya está capturada. A partir de ahí la
# matrícula se crea completando lo que falte, y si de verdad no se puede crear, la
# transacción queda en authorized_error con la respuesta guardada para reprocesar —
# nunca como "failed", que es lo que dejó el cobro invisible.
class TransbankCallbackTest < ActionDispatch::IntegrationTest
  setup do
    teacher_user = User.create!(email: "profe.cb@test.cl", password: "password123", name: "Profe CB")
    teacher = Teacher.create!(user: teacher_user, profession: "Artista")
    @course = Course.create!(title: "Óleo Callback", description: "curso de prueba")
    @section = Section.create!(
      course: @course, teacher: teacher, places: 8, weekday: "Sábado",
      schedule: [{ "start_time" => "12:30", "end_time" => "14:30" }]
    )
    @plan = WeeklyPlan.create!(plan: "Plan mensual", description: "4 clases mensuales",
                               number_of_classes: 4, weekly_classes: 1, price: 40_000,
                               saturday_price: 45_000, course: @course)
    @cuatro_meses = PaymentPeriod.create!(months: 4, discount_percentage: 20, description: "4 meses")
    PaymentMethod.create!(payment_method: "Webpay")
    ClassDiscount.create!(number_of_classes: 4, discount_percentage: 0)
    ClassDiscount.create!(number_of_classes: 16, discount_percentage: 20)
    # Un admin para que el aviso interno tenga destinatario. OJO: no puede ser un
    # correo @test.* — User.admin_notification_emails los descarta a propósito.
    admin_user = User.create!(email: "admin.cb@gustarte.cl", password: "password123", name: "Admin CB")
    AdminUser.create!(user: admin_user, admin_type: "general")

    primer_sabado = Date.current.next_occurring(:saturday) + 7
    @fechas = (0..15).map { |i| (primer_sabado + (i * 7)).to_s }
    ENV["FRONTEND_URL"] = "https://gustarte.test"
  end

  teardown { ENV.delete("FRONTEND_URL") }

  def transaccion(dates)
    TransbankTransaction.create!(
      token: "token-#{SecureRandom.hex(6)}",
      buy_order: "PEND-#{SecureRandom.hex(4)}",
      amount: 144_000,
      status: "pending",
      payment_type: "enrollment_fee",
      enrollment_data: {
        enrollments: [{
          name: "Ximena Callback", email: "ximena.cb@example.cl", phone: "985624216",
          start_date: dates.first, section_ids: [@section.id],
          section_dates: { @section.id.to_s => dates },
          weekly_plan_id: @plan.id, payment_period_id: @cuatro_meses.id
        }]
      }
    )
  end

  def respuesta_aprobada(transaction)
    {
      "vci" => "TSY", "amount" => 144_000, "status" => "AUTHORIZED",
      "buy_order" => transaction.buy_order, "session_id" => "sesion-test",
      "card_detail" => { "card_number" => "2655" },
      "accounting_date" => "0803", "transaction_date" => "2026-08-03T20:42:13.014Z",
      "authorization_code" => "221646", "payment_type_code" => "VD",
      "response_code" => 0, "installments_number" => 0
    }
  end

  def con_transbank_aprobando(transaction, &block)
    fake = Object.new
    respuesta = respuesta_aprobada(transaction)
    fake.define_singleton_method(:commit) { |_token| respuesta }
    Transbank::Webpay::WebpayPlus::Transaction.stub(:new, fake, &block)
  end

  test "completa las fechas que faltan y deja la transacción marcada para revisar" do
    transaction = transaccion(@fechas.first(13))

    con_transbank_aprobando(transaction) do
      get "/transbank/callback", params: { token_ws: transaction.token }
    end

    transaction.reload
    assert_equal "authorized", transaction.status
    assert transaction.needs_review?, "tiene que quedar marcada para revisión"
    assert_match(/Se completaron 3 clase/, transaction.error_message)

    enrollment = transaction.enrollment
    assert_equal 16, enrollment.enrollment_sections.count
    assert_equal 1, enrollment.payments.count
    pago = enrollment.payments.first
    assert_equal 144_000, pago.amount.to_i
    assert_equal "221646", pago.reference_number
    # La fecha del pago es la del cobro en Transbank, no la de hoy
    assert_equal Date.new(2026, 8, 3), pago.payment_date

    assert_match "/payment/success", response.headers["Location"]
  end

  test "un cobro que no se puede convertir en matrícula queda en authorized_error, no en failed" do
    # Una fecha en domingo: la sección es de sábado, así que no hay forma de crearla
    fechas = @fechas.dup
    fechas[3] = (Date.parse(fechas[3]) + 1).to_s
    transaction = transaccion(fechas)

    con_transbank_aprobando(transaction) do
      get "/transbank/callback", params: { token_ws: transaction.token }
    end

    transaction.reload
    assert_equal "authorized_error", transaction.status, "failed borraría el rastro del cobro"
    assert transaction.needs_review?
    assert_match(/COBRADO SIN MATRÍCULA/, transaction.error_message)

    # Todo lo necesario para reprocesar sin volver a preguntarle a Transbank
    assert_equal "221646", transaction.authorization_code
    assert_equal "2655", transaction.card_number
    assert transaction.raw_response.present?
    assert_nil transaction.enrollment_id
    assert_equal 0, Payment.count

    # A la alumna NUNCA se le muestra "pago fallido" si le cobraron
    assert_match "/payment/success", response.headers["Location"]
    assert_match "enrollment_pending=1", response.headers["Location"]
  end

  test "reprocesar crea la matrícula con la respuesta guardada" do
    fechas = @fechas.dup
    fechas[3] = (Date.parse(fechas[3]) + 1).to_s
    transaction = transaccion(fechas)

    con_transbank_aprobando(transaction) do
      get "/transbank/callback", params: { token_ws: transaction.token }
    end
    assert_equal "authorized_error", transaction.reload.status

    # El admin corrige el dato y reprocesa (mismo camino que el botón del panel)
    data = transaction.enrollment_data
    data["enrollments"][0]["section_dates"][@section.id.to_s] = @fechas
    transaction.update_columns(enrollment_data: data)

    transaction.reprocess!
    transaction.reload

    assert_equal "authorized", transaction.status
    assert_equal 16, transaction.enrollment.enrollment_sections.count
    assert_equal 144_000, transaction.enrollment.payments.first.amount.to_i
  end

  test "el aviso interno a los admins se puede renderizar" do
    transaction = transaccion(@fechas.first(13))
    mail = AdminAlertMailer.transbank_incident(transaction, "COBRO SIN MATRÍCULA: prueba").message

    assert_equal ["admin.cb@gustarte.cl"], mail.to
    assert_match(/Revisar pago/, mail.subject)
    cuerpo = mail.body.decoded
    assert_match(/ximena.cb@example.cl/, cuerpo)
    assert_match(/144\.000/, cuerpo, "el monto tiene que salir con formato chileno")
    assert_match(/NO se creó/, cuerpo)
  end
end
