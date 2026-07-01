# Arquitectura del proyecto

Sistema de gestión para una academia (contexto Chile). Administra cursos, secciones,
profesores, estudiantes, inscripciones, asistencia, planes/precios y pagos —
incluyendo cobro en línea vía **Transbank Webpay Plus**. La interfaz de administración
está en español.

## Stack

| Capa | Tecnología |
|------|------------|
| Lenguaje / Framework | Ruby 3.3.2 · Rails 7.1.3 |
| Base de datos | PostgreSQL |
| Autenticación | Devise |
| Autorización | CanCanCan |
| Front del panel admin | Server-rendered ERB + Hotwire (Turbo + Stimulus), importmap, Sprockets |
| API pública | JSON bajo `/api/v1` (consumida por un frontend SPA externo) |
| Pagos | `transbank-sdk` (Webpay Plus) |
| Paginación | Kaminari |
| Servidor | Puma |

## Forma general de la aplicación (híbrida)

Este backend Rails cumple **dos roles a la vez**:

1. **Panel de administración server-rendered** (`/admin/*`, layout `admin`) — usado
   por administradores y profesores. Vistas ERB tradicionales con Hotwire.
2. **API JSON** (`/api/v1/*`) — consumida por un **frontend SPA separado** (Vite/React,
   `gustarte.cl` en producción; ver `config/initializers/cors.rb` y la env `FRONTEND_URL`).
   La SPA maneja el flujo público de inscripción y pago con tarjeta.

El callback de Transbank vive en el backend (`/transbank/callback`) y, tras confirmar
el pago, redirige de vuelta a la SPA (`FRONTEND_URL/payment/success|failure`).

## Roles y autorización

Un `User` (Devise) tiene **uno** de tres perfiles vía asociaciones `has_one`:
`admin_user`, `teacher` o `student`. El registro público está deshabilitado —
**solo los administradores crean usuarios**.

Las reglas están centralizadas en `app/models/ability.rb` (CanCanCan):

- **Admin** (`user.admin_user`): `can :manage, :all`.
- **Teacher** (`user.teacher`): solo lectura del dashboard; lectura de sus cursos y
  secciones asignadas; tomar asistencia en sus secciones; ver estudiantes inscritos
  en ellas; gestionar recuperatorios de esas secciones.
- **Student** / invitado: sin acceso al panel admin.

`Admin::ApplicationController` fuerza `authenticate_user!` + `check_admin_or_teacher_access!`
y captura `CanCan::AccessDenied` redirigiendo a `unauthorized_path`. La API v1
(`Api::V1::BaseController`) deshabilita CSRF pero **no** aplica autenticación por sí misma.

## Modelo de dominio

```
User ──has_one── AdminUser / Teacher / Student
                    │            │
        Teacher ────┤            └──── Student
          │ has_many                     │ has_many
          ▼                              ▼
        Section ◄──── Course          Enrollment ──► WeeklyPlan (plan/precio)
          │ has_many    (has_many        │           ──► PaymentPeriod (descuento)
          │              sections)        │           ──► PaymentMethod
          │                               │ has_many
          └──────► EnrollmentSection ◄────┘ has_many ─► Payment
                   (una fila por CLASE:            └──► TransbankTransaction
                    fecha + asistencia)
```

Entidades clave:

- **Course** → tiene muchas **Sections**. Una Section pertenece a un Course y a un
  Teacher; tiene `places` (cupos), `weekday` y un `schedule` (JSON, un solo bloque
  `start_time`/`end_time`).
- **Enrollment** — la inscripción de un Student. Referencia un `WeeklyPlan`, un
  `PaymentPeriod` (implícito vía cálculo) y un `PaymentMethod`; guarda
  `enrollment_amount` y `total_tuition_fee` ya calculados.
- **EnrollmentSection** — la tabla central: **una fila por clase individual**
  (`enrollment` + `section` + `date`). Ahí se registra `attended` (asistencia). Es
  única por `(enrollment, section, date)` y valida cupos disponibles para la fecha.
  Soporta **recuperatorios** (ver abajo).
- **WeeklyPlan** — el "producto"/plan: precio, `saturday_price`, `enrollment_fee`,
  `number_of_classes`, `weekly_classes`, `event_type` (`trial`/`special_event`).
  Contiene la lógica de precio final (`calculate_final_price`, `determine_base_price`).
- **PaymentPeriod** — `months` + `discount_percentage` (descuento por pagar varios meses).
- **PaymentMethod** — catálogo (efectivo, transferencia, Webpay, etc.).
- **Payment** — pago registrado (`payment_type: enrollment_fee`;
  `status: completed/pending/refunded`); puede tener `processed_by` (User admin).
- **TransbankTransaction** — una transacción Webpay (`status: pending/authorized/failed/nullified`).
- **TeacherPayment** — pagos a profesores por período (`status: pending/paid/cancelled`).

## Clases de recuperatorio (makeup)

`EnrollmentSection` distingue `kind` = `regular` | `makeup` y se auto-referencia con
`makes_up_for_id` (una clase de recuperatorio apunta a la clase regial ausentada).
Reglas validadas en el modelo:

- Solo se puede recuperar una clase con **falta confirmada** (`attended == false`).
- El recuperatorio debe pertenecer al **mismo enrollment**.
- La fecha debe caer **dentro del período del plan contratado** (rango entre la primera
  y última clase regular), salvo que el admin use `skip_period_rule` para hacer una excepción.
- Relación 1:1 (índice único en `makes_up_for_id`).

## Flujo de inscripción y pago

### Creación de inscripciones — `app/services/enrollment_creator.rb`

`EnrollmentCreator` es el servicio que orquesta, dentro de una transacción DB:

1. Encuentra o crea `User` + `Student` (con contraseña temporal si es nuevo).
2. Calcula montos desde el `WeeklyPlan` (aplica `saturday_price` y descuento del período).
3. Crea el `Enrollment`.
4. Genera las `EnrollmentSection` (una por clase) — ya sea con **fechas específicas**
   provistas por el usuario, o generándolas automáticamente desde una `start_date`
   avanzando semana a semana y saltando fechas sin cupo.
5. Crea el `Payment` de inscripción **solo** para métodos offline (efectivo/transferencia);
   para pagos con tarjeta/Webpay el pago se crea después, en el callback de Transbank.

### Pago en línea — Transbank Webpay Plus

Config en `config/initializers/transbank.rb` (`TransbankConfig`): usa credenciales de
**producción** solo si `Rails.env.production?` **y** ambas envs
(`TRANSBANK_COMMERCE_CODE`, `TRANSBANK_API_KEY`) están presentes; si no, cae a las de
integración. Ver también `docs/transbank_integration.md`.

Flujo (`app/controllers/transbank_controller.rb`):

1. La SPA inicia una transacción; se guarda una `TransbankTransaction` en estado
   `pending` con los datos de inscripción en `enrollment_data` (JSON) — la inscripción
   **aún no existe** en la DB.
2. Webpay redirige a `/transbank/callback` con `token_ws`.
3. El callback hace `tx.commit(token)`. Si `response_code == 0`:
   `mark_as_authorized!` crea la(s) inscripción(es) desde `enrollment_data` (vía
   `EnrollmentCreator`), crea el/los `Payment` `completed`, y marca la transacción
   `authorized`.
4. Redirige a la SPA (`FRONTEND_URL/payment/success` o `/failure`). Se maneja también
   la cancelación del usuario (`TBK_ORDEN_COMPRA` sin `token_ws`).

Soporta **múltiples inscripciones** en una sola transacción (`enrollment_data.enrollments`).

## Estructura de rutas

- `/admin/*` — panel completo: dashboard, courses, sections (con `take_attendance`),
  enrollments, enrollment_sections (edición + `makeup`/`assign_makeup`), users,
  weekly_plans, payment_periods, payment_methods, payments (+ `export` CSV),
  transbank_transactions, teacher_payments, profile. Root del sitio (`/`) apunta aquí.
- `/api/v1/*` — courses, sections (`calendar`, `preview_class_dates`), weekly_plans,
  payment_periods, payment_methods, enrollments (`create`), teachers (`dashboard`),
  users (`find_by_email`). Consumida por la SPA.
- `/students/payments` — pago de la cuota de inscripción por parte del estudiante.
- `/transbank/*` — callback y páginas de resultado.
- `/users/*` — Devise (login, recuperación de contraseña; sin registro).

## Organización del código

```
app/
├── controllers/
│   ├── admin/        # panel server-rendered (hereda de Admin::ApplicationController)
│   ├── api/v1/       # API JSON (hereda de Api::V1::BaseController)
│   ├── students/     # pagos del estudiante
│   └── transbank_controller.rb
├── models/           # dominio + ability.rb (CanCanCan)
├── services/
│   ├── enrollment_creator.rb            # crea inscripción + secciones + pago
│   └── financial_report_csv_exporter.rb # export de reporte financiero
└── views/            # admin/, devise/, students/, transbank/, layouts/, pages/
config/initializers/  # transbank.rb, cors.rb, devise.rb, ...
```

No hay jobs en background propios (solo `ApplicationJob`) ni mailers personalizados
(solo `ApplicationMailer`) al momento de escribir este documento.

## Notas de configuración

- **CORS** (`config/initializers/cors.rb`): orígenes permitidos incluyen localhost de
  dev (3000/5173/4200/8080), `gustarte.cl`/`www.gustarte.cl` y `ENV['FRONTEND_URL']`,
  con `credentials: true`.
- **Credenciales / seeds**: `db/seeds.rb` crea usuarios de prueba con contraseñas fijas
  (ver el recuerdo *Seed credentials*).
- El esquema real vive en `db/schema.rb` (fuente de verdad de la estructura de tablas).
