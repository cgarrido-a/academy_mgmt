require "test_helper"
require "minitest/mock"

# El candado que faltaba el 3-ago-2026: si la inscripción no se puede crear, el cobro
# NO debe empezar. Antes se iniciaba la transacción con Transbank igual y el error
# recién aparecía en el callback, con la plata ya capturada.
class Api::V1::EnrollmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    teacher_user = User.create!(email: "profe.api@test.cl", password: "password123", name: "Profe API")
    teacher = Teacher.create!(user: teacher_user, profession: "Artista")
    @course = Course.create!(title: "Óleo API", description: "curso de prueba")
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

    primer_sabado = Date.current.next_occurring(:saturday) + 7
    @fechas = (0..15).map { |i| (primer_sabado + (i * 7)).to_s }
  end

  def payload(dates)
    {
      enrollments: [{
        name: "Ximena Test",
        email: "ximena.api@example.cl",
        phone: "985624216",
        start_date: dates.first,
        section_ids: [@section.id],
        section_dates: { @section.id.to_s => dates },
        weekly_plan_id: @plan.id,
        payment_period_id: @cuatro_meses.id
      }]
    }
  end

  test "rechaza con 422 y sin cobrar cuando faltan fechas para el plan" do
    assert_no_difference "TransbankTransaction.count" do
      post "/api/v1/enrollments", params: payload(@fechas.first(13)), as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal false, body["success"]
    assert_match(/16 fechas/, body["error"])
    # Tampoco puede haber quedado la alumna a medio crear
    assert_nil User.find_by(email: "ximena.api@example.cl")
  end

  test "rechaza con 422 cuando sobran fechas" do
    fechas = @fechas + [(Date.parse(@fechas.last) + 7).to_s]

    assert_no_difference "TransbankTransaction.count" do
      post "/api/v1/enrollments", params: payload(fechas), as: :json
    end

    assert_response :unprocessable_entity
    assert_match(/17 fechas y el plan es de 16/, JSON.parse(response.body)["error"])
  end

  test "inicia el cobro cuando el payload cuadra con el plan" do
    fake_tx = Minitest::Mock.new
    fake_tx.expect(:create, {
      "token" => "token-de-prueba-123",
      "url" => "https://webpay3gint.transbank.cl/webpayserver/initTransaction"
    }, [String, String, Integer, String])

    ENV["BACKEND_URL"] = "https://back-academia.test"

    Transbank::Webpay::WebpayPlus::Transaction.stub(:new, fake_tx) do
      assert_difference "TransbankTransaction.count", 1 do
        post "/api/v1/enrollments", params: payload(@fechas), as: :json
      end
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["success"]
    assert_equal 144_000, body["transbank_payment"]["amount"].to_i

    transaction = TransbankTransaction.order(:id).last
    assert_equal "pending", transaction.status
    assert_nil transaction.enrollment_id, "la matrícula se crea recién en el callback"
    assert_equal 16, transaction.enrollment_data["enrollments"].first["section_dates"][@section.id.to_s].size

    # La validación previa no deja rastro: nada creado antes de que pague
    assert_nil User.find_by(email: "ximena.api@example.cl")
    fake_tx.verify
  ensure
    ENV.delete("BACKEND_URL")
  end

  test "rechaza con 422 si el curso está cerrado" do
    @course.update!(active: false)

    assert_no_difference "TransbankTransaction.count" do
      post "/api/v1/enrollments", params: payload(@fechas), as: :json
    end

    assert_response :unprocessable_entity
    assert_match(/cerradas/, JSON.parse(response.body)["error"])
  end
end
