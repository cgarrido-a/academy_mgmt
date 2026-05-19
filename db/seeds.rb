require 'securerandom'

puts "\nSeeding academy_mgmt..."

# ============================================================
# Payment Methods
# ============================================================
puts "  PaymentMethods..."
%w[Efectivo Webpay Transferencia].each { |m| PaymentMethod.create!(payment_method: m) }
webpay        = PaymentMethod.find_by!(payment_method: 'Webpay')
efectivo      = PaymentMethod.find_by!(payment_method: 'Efectivo')
transferencia = PaymentMethod.find_by!(payment_method: 'Transferencia')

# ============================================================
# Payment Periods
# ============================================================
puts "  PaymentPeriods..."
payment_periods = [
  { months: 1,  discount_percentage: 0,  description: 'Mensual' },
  { months: 3,  discount_percentage: 5,  description: 'Trimestral (5% dcto)' },
  { months: 6,  discount_percentage: 10, description: 'Semestral (10% dcto)' },
  { months: 12, discount_percentage: 15, description: 'Anual (15% dcto)' }
].map { |attrs| PaymentPeriod.create!(attrs) }

# ============================================================
# Weekly Plans
# ============================================================
puts "  WeeklyPlans..."
plans = [
  WeeklyPlan.create!(plan: '1 clase semanal',    description: '1 clase de 60 min por semana',
                     weekly_classes: 1, number_of_classes: 4,  price: 35_000, saturday_price: 40_000, enrollment_fee: 20_000),
  WeeklyPlan.create!(plan: '2 clases semanales', description: '2 clases de 60 min por semana',
                     weekly_classes: 2, number_of_classes: 8,  price: 60_000, saturday_price: 70_000, enrollment_fee: 20_000),
  WeeklyPlan.create!(plan: '3 clases semanales', description: '3 clases de 60 min por semana',
                     weekly_classes: 3, number_of_classes: 12, price: 80_000, saturday_price: 90_000, enrollment_fee: 20_000),
  WeeklyPlan.create!(plan: 'Clase de prueba',    description: 'Clase única gratuita de prueba',
                     weekly_classes: 1, number_of_classes: 1,  price: 1,     enrollment_fee: 0, event_type: WeeklyPlan.event_types[:trial]),
  WeeklyPlan.create!(plan: 'Taller intensivo',   description: 'Taller especial de 4 sesiones',
                     weekly_classes: 2, number_of_classes: 4,  price: 50_000, saturday_price: 60_000, enrollment_fee: 0,
                     event_type: WeeklyPlan.event_types[:special_event])
]
regular_plans = plans.first(3)

# ============================================================
# Users + Admins + Teachers + Students
# ============================================================
puts "  Users + roles..."
PASSWORD = 'password123'

admin_main = User.create!(name: 'Admin Demo', email: 'admin@academy.test',
                          phone: '+56911111111', password: PASSWORD)
admin_main.create_admin_user!(admin_type: 'super')

admin_extra = User.create!(name: 'Carmen Soto', email: 'carmen.soto@academy.test',
                           phone: '+56922222222', password: PASSWORD)
admin_extra.create_admin_user!(admin_type: 'staff')

teacher_main_user = User.create!(name: 'Profe Demo', email: 'profe@academy.test',
                                 phone: '+56933333333', password: PASSWORD)
teacher_main = teacher_main_user.create_teacher!(profession: 'Profesora de Música')

teacher_data = [
  ['Daniela Pérez', 'daniela.perez@academy.test', '+56944444441', 'Profesora de Danza'],
  ['Javier López',  'javier.lopez@academy.test',  '+56944444442', 'Profesor de Yoga'],
  ['Ricardo Muñoz', 'ricardo.munoz@academy.test', '+56944444443', 'Profesor de Guitarra'],
  ['Sofía Rojas',   'sofia.rojas@academy.test',   '+56944444444', 'Profesora de Inglés'],
  ['Andrés Vidal',  'andres.vidal@academy.test',  '+56944444445', 'Profesor de Pintura']
]
teachers = [teacher_main] + teacher_data.map do |name, email, phone, prof|
  u = User.create!(name: name, email: email, phone: phone, password: PASSWORD)
  u.create_teacher!(profession: prof)
end

student_main_user = User.create!(name: 'Estudiante Demo', email: 'estudiante@academy.test',
                                 phone: '+56955555555', password: PASSWORD)
student_main = student_main_user.create_student!

first_names = %w[Camila Matías Valentina Benjamín Florencia Joaquín Antonia Vicente
                 Isidora Cristóbal María Diego Constanza Felipe Catalina Tomás
                 Martina Lucas Emilia Agustín Renata Ignacio Fernanda Pablo
                 Daniela Sebastián Josefa Nicolás Amanda Bastián Laura Mauricio
                 Paula Andrés Trinidad Rocío Maximiliano Antonella Eduardo Javiera]
last_names = %w[González Muñoz Rojas Díaz Pérez Soto Contreras Silva Martínez
                Sepúlveda Morales Rodríguez López Fuentes Hernández Torres Araya
                Flores Espinoza Valenzuela Castillo Tapia Reyes Carrasco Jara
                Vargas Riquelme Cortés Vásquez Saavedra]

students = [student_main]
39.times do |i|
  fn  = first_names.sample
  ln1 = last_names.sample
  ln2 = last_names.sample
  email = "estudiante#{i + 1}@example.test"
  u = User.create!(
    name:  "#{fn} #{ln1} #{ln2}",
    email: email,
    phone: "+5699#{rand(10_000_000..99_999_999)}",
    password: PASSWORD
  )
  students << u.create_student!
end

# ============================================================
# Courses
# ============================================================
puts "  Courses..."
courses = [
  ['Música para niños',     'Iniciación musical para niños de 6 a 12 años'],
  ['Yoga para adultos',     'Clases de yoga para todos los niveles'],
  ['Guitarra acústica',     'Aprende guitarra desde cero'],
  ['Inglés conversacional', 'Conversación práctica en inglés'],
  ['Pintura al óleo',       'Técnicas de pintura al óleo'],
  ['Danza moderna',         'Coreografías de danza contemporánea']
].map { |title, desc| Course.create!(title: title, description: desc) }

# ============================================================
# Sections (18: 3 por curso, algunos profes con varias secciones del mismo curso)
# ============================================================
puts "  Sections..."

# teachers[0] = Profe Demo (Música)
# teachers[1] = Daniela Pérez (Danza)
# teachers[2] = Javier López (Yoga)
# teachers[3] = Ricardo Muñoz (Guitarra)
# teachers[4] = Sofía Rojas (Inglés)
# teachers[5] = Andrés Vidal (Pintura)
profe_demo, daniela, javier, ricardo, sofia, andres = teachers

# Distribución intencional: cada curso tiene 3 secciones, varios profes con múltiples
# secciones del mismo curso (caso de uso para recuperatorios entre secciones del mismo profe).
section_specs = [
  # Música para niños — Profe Demo dicta DOS secciones
  { course: courses[0], teacher: profe_demo, weekday: 'Lunes',     schedule: '09:00-10:00', places: 12 },
  { course: courses[0], teacher: profe_demo, weekday: 'Miércoles', schedule: '17:00-18:00', places: 10 },
  { course: courses[0], teacher: daniela,    weekday: 'Sábado',    schedule: '11:00-12:00', places: 15 },
  # Yoga para adultos — Javier dicta las tres
  { course: courses[1], teacher: javier,     weekday: 'Martes',    schedule: '08:00-09:00', places: 12 },
  { course: courses[1], teacher: javier,     weekday: 'Jueves',    schedule: '19:00-20:00', places: 12 },
  { course: courses[1], teacher: javier,     weekday: 'Sábado',    schedule: '10:00-11:00', places: 15 },
  # Guitarra acústica — Ricardo dicta dos
  { course: courses[2], teacher: ricardo,    weekday: 'Lunes',     schedule: '18:30-19:30', places: 8 },
  { course: courses[2], teacher: ricardo,    weekday: 'Viernes',   schedule: '18:00-19:00', places: 8 },
  { course: courses[2], teacher: daniela,    weekday: 'Sábado',    schedule: '15:00-16:00', places: 10 },
  # Inglés conversacional — Sofía dicta las tres
  { course: courses[3], teacher: sofia,      weekday: 'Lunes',     schedule: '10:00-11:00', places: 10 },
  { course: courses[3], teacher: sofia,      weekday: 'Martes',    schedule: '19:00-20:00', places: 10 },
  { course: courses[3], teacher: sofia,      weekday: 'Jueves',    schedule: '17:00-18:00', places: 12 },
  # Pintura al óleo — Andrés dicta dos
  { course: courses[4], teacher: andres,     weekday: 'Miércoles', schedule: '16:00-17:30', places: 10 },
  { course: courses[4], teacher: andres,     weekday: 'Viernes',   schedule: '16:00-17:30', places: 10 },
  { course: courses[4], teacher: profe_demo, weekday: 'Sábado',    schedule: '14:00-15:30', places: 12 },
  # Danza moderna — Daniela dicta dos
  { course: courses[5], teacher: daniela,    weekday: 'Martes',    schedule: '18:00-19:00', places: 15 },
  { course: courses[5], teacher: daniela,    weekday: 'Jueves',    schedule: '18:00-19:00', places: 15 },
  { course: courses[5], teacher: profe_demo, weekday: 'Sábado',    schedule: '16:00-17:00', places: 12 }
]

sections = section_specs.map do |spec|
  start_time, end_time = spec[:schedule].split('-')
  Section.create!(
    course: spec[:course], teacher: spec[:teacher],
    weekday: spec[:weekday],
    schedule: [{ 'start_time' => start_time, 'end_time' => end_time }],
    places: spec[:places]
  )
end

# ============================================================
# Enrollments + EnrollmentSections + Payments
# ============================================================
puts "  Enrollments + asistencia + pagos..."
WDAY = Section::WEEKDAY_TO_WDAY
today = Date.current

created = 0
attempts = 0
target = 60

# Periods con peso: más 6 y 12 meses para tener fechas futuras de varios meses
weighted_periods = payment_periods.flat_map do |p|
  case p.months
  when 1  then [p] * 1
  when 3  then [p] * 2
  when 6  then [p] * 4
  when 12 then [p] * 3
  else [p]
  end
end

while created < target && attempts < target * 6
  attempts += 1
  student = students.sample
  section = sections.sample
  plan    = regular_plans.sample
  period  = weighted_periods.sample

  # Sesgar fechas de inicio: la mayoría arrancan recientemente o pronto,
  # para que las clases caigan en los próximos ~12 meses.
  base_date = today + (rand(-6..6) * 7)
  section_wday = WDAY[section.weekday]
  diff = (section_wday - base_date.wday) % 7
  first_class = base_date + diff

  total_classes = plan.number_of_classes * (period.months || 1)
  class_dates = (0...total_classes).map { |k| first_class + (k * 7) }

  blocked = class_dates.any? do |d|
    EnrollmentSection.where(section_id: section.id, date: d).count >= section.places
  end
  next if blocked

  duplicate = class_dates.any? do |d|
    EnrollmentSection.exists?(enrollment: student.enrollments, section_id: section.id, date: d)
  end
  next if duplicate

  begin
    ActiveRecord::Base.transaction do
      enrollment_amount = plan.enrollment_fee || 0
      total_tuition_fee = plan.calculate_final_price(period, section_ids: [section.id]) || 0
      pm = [webpay, efectivo, transferencia].sample

      enrollment = Enrollment.create!(
        student: student, weekly_plan: plan, payment_method: pm,
        enrollment_amount: enrollment_amount,
        total_tuition_fee: total_tuition_fee,
        payment_date: first_class - 7
      )

      class_dates.each do |d|
        attended_val = d <= today ? [true, true, true, false].sample : nil
        EnrollmentSection.create!(enrollment: enrollment, section: section,
                                  date: d, attended: attended_val)
      end

      if enrollment_amount > 0
        Payment.create!(
          enrollment: enrollment, payment_method: pm,
          payment_type: 'enrollment_fee', amount: enrollment_amount,
          payment_date: first_class - 7, status: 'completed',
          processed_by: admin_main,
          reference_number: "REF-#{SecureRandom.hex(4).upcase}"
        )
      end
    end
    created += 1
  rescue ActiveRecord::RecordInvalid
    next
  end
end

# ============================================================
# Asegurar al menos una inscripción para el estudiante fijo
# ============================================================
if student_main.enrollments.empty?
  section = sections.sample
  plan    = regular_plans.first
  period  = payment_periods.first
  base = today - 14
  diff = (WDAY[section.weekday] - base.wday) % 7
  first_class = base + diff
  dates = (0...plan.number_of_classes).map { |k| first_class + (k * 7) }
  dates = dates.reject { |d| EnrollmentSection.where(section_id: section.id, date: d).count >= section.places }

  if dates.any?
    ActiveRecord::Base.transaction do
      enr = Enrollment.create!(
        student: student_main, weekly_plan: plan, payment_method: webpay,
        enrollment_amount: plan.enrollment_fee,
        total_tuition_fee: plan.calculate_final_price(period, section_ids: [section.id]),
        payment_date: base
      )
      dates.each do |d|
        EnrollmentSection.create!(enrollment: enr, section: section, date: d,
                                  attended: d <= today ? [true, false].sample : nil)
      end
      Payment.create!(enrollment: enr, payment_method: webpay,
                      payment_type: 'enrollment_fee', amount: plan.enrollment_fee,
                      payment_date: base, status: 'completed', processed_by: admin_main,
                      reference_number: "REF-#{SecureRandom.hex(4).upcase}")
    end
  end
end

# ============================================================
# TeacherPayments (uno pagado del mes anterior, uno pendiente del actual)
# ============================================================
puts "  TeacherPayments..."
last_month_start = (today.beginning_of_month << 1)
last_month_end   = today.beginning_of_month - 1
this_month_start = today.beginning_of_month
this_month_end   = today.end_of_month
rate_per_class = 8_000

teachers.each do |teacher|
  attended_last = EnrollmentSection.joins(:section)
                    .where(sections: { teacher_id: teacher.id })
                    .where(date: last_month_start..last_month_end, attended: true)
                    .count
  if attended_last.positive?
    TeacherPayment.create!(
      teacher: teacher, payment_method: transferencia,
      amount: attended_last * rate_per_class,
      status: 'paid', payment_date: last_month_end + 5,
      period_start: last_month_start, period_end: last_month_end,
      notes: "Pago mes #{last_month_start.strftime('%m/%Y')} (#{attended_last} clases asistidas)"
    )
  end

  attended_now = EnrollmentSection.joins(:section)
                   .where(sections: { teacher_id: teacher.id })
                   .where(date: this_month_start..today, attended: true)
                   .count
  if attended_now.positive?
    TeacherPayment.create!(
      teacher: teacher, payment_method: transferencia,
      amount: attended_now * rate_per_class,
      status: 'pending',
      period_start: this_month_start, period_end: this_month_end,
      notes: "En curso mes #{this_month_start.strftime('%m/%Y')} (#{attended_now} clases hasta hoy)"
    )
  end
end

# ============================================================
# TransbankTransactions (algunas autorizadas)
# ============================================================
puts "  TransbankTransactions..."
Enrollment.where(payment_method_id: webpay.id).limit(15).each do |enr|
  next if enr.enrollment_amount.to_i <= 0
  TransbankTransaction.create!(
    enrollment: enr, payment_type: 'enrollment_fee',
    token: "TBK#{SecureRandom.hex(16)}",
    buy_order: "ENR#{enr.id}-FEE-#{Time.now.to_i}-#{SecureRandom.hex(2)}",
    amount: enr.enrollment_amount,
    status: 'authorized',
    authorization_code: SecureRandom.hex(3).upcase,
    payment_type_code: 'VD', response_code: 0,
    card_number: "XXXX-XXXX-XXXX-#{rand(1000..9999)}",
    transaction_date: enr.payment_date || Date.current,
    raw_response: '{"status":"AUTHORIZED"}'
  )
end

# ============================================================
# Summary
# ============================================================
puts "\nDone."
puts "----------------------------------------------"
puts "PaymentMethods:        #{PaymentMethod.count}"
puts "PaymentPeriods:        #{PaymentPeriod.count}"
puts "WeeklyPlans:           #{WeeklyPlan.count}"
puts "Users:                 #{User.count}"
puts "  Admins:              #{AdminUser.count}"
puts "  Teachers:            #{Teacher.count}"
puts "  Students:            #{Student.count}"
puts "Courses:               #{Course.count}"
puts "Sections:              #{Section.count}"
puts "Enrollments:           #{Enrollment.count}"
puts "EnrollmentSections:    #{EnrollmentSection.count}"
puts "Payments:              #{Payment.count}"
puts "TeacherPayments:       #{TeacherPayment.count}"
puts "TransbankTransactions: #{TransbankTransaction.count}"
puts "----------------------------------------------"
puts "\nCredenciales (password: #{PASSWORD}):"
puts "  Admin:      admin@academy.test"
puts "  Profe:      profe@academy.test"
puts "  Estudiante: estudiante@academy.test"
puts ""
