# Integración con Transbank Webpay Plus

Este documento describe cómo funciona la integración con Transbank Webpay Plus para
pagos online. Refleja el comportamiento real del código; ver también
`docs/arquitectura.md` para el panorama general del proyecto.

## Descripción General

El sistema cobra la matrícula/arancel de una inscripción a través de Transbank Webpay
Plus. Existen **dos entradas** al mismo flujo de pago:

1. **Inscripción nueva desde la SPA** (`POST /api/v1/enrollments`): se inicia el pago
   **antes** de crear la inscripción. La inscripción se materializa recién cuando el
   pago se confirma en el callback.
2. **Pago de una inscripción ya existente** (`POST /students/payments/pay_enrollment_fee/:enrollment_id`):
   la inscripción ya existe en la base de datos y solo falta pagar su arancel.

Ambos terminan en el mismo callback (`/transbank/callback`), que confirma la
transacción con Transbank y crea el/los `Payment` correspondientes.

## Flujo 1 — Inscripción nueva desde la SPA (principal)

Punto clave: **no se crea Student ni Enrollment al iniciar el pago**. El controller lo
dice explícitamente (*"Initialize Transbank payment WITHOUT creating enrollments.
Enrollments will be created after successful payment"*). Los datos de la inscripción se
guardan como JSON en `enrollment_data` y se usan luego para crear todo.

```
1. Frontend (SPA) → POST /api/v1/enrollments  (body: { enrollments: [ {...}, ... ] })
2. Backend → Calcula el monto total sumando cada enrollment (WeeklyPlan + PaymentPeriod)
3. Backend → tx.create(...) con Transbank → obtiene token + url
4. Backend → Crea TransbankTransaction (status: pending, enrollment_id: nil,
             enrollment_data: { enrollments: [...] }, buy_order: "PEND-{timestamp}")
5. Backend → Responde JSON con { success, message, transbank_payment: {...} }
6. Frontend → Redirige el navegador a transbank_payment.full_url
7. Cliente → Paga en Transbank
8. Transbank → Redirige a BACKEND_URL/transbank/callback (con token_ws)
9. Backend → tx.commit(token)
10. Backend → Si aprobado (response_code == 0): mark_as_authorized!
    - Crea la(s) inscripción(es) desde enrollment_data (vía EnrollmentCreator)
    - Crea un Payment (status: completed) por cada inscripción
    - Actualiza la TransbankTransaction (status: authorized, code, tarjeta, etc.)
11. Backend → Redirige a FRONTEND_URL/payment/success (o /failure si rechazado/cancelado)
```

### Request

`POST /api/v1/enrollments` espera **un array** bajo la clave `enrollments`. Cada
elemento acepta (ver `Api::V1::EnrollmentsController#enrollments_params`):

```json
{
  "enrollments": [
    {
      "name": "Juan Pérez",
      "email": "juan@example.com",
      "phone": "+56912345678",
      "start_date": "2026-03-02",
      "weekly_plan_id": 1,
      "payment_method_id": 2,
      "payment_period_id": 1,
      "section_ids": [3, 4],
      "section_dates": { "3": ["2026-03-02", "..."] }
    }
  ]
}
```

Notas:
- Usa `weekly_plan_id` y `payment_period_id` (no existe `payment_plan_id`).
- `section_ids` (array) o `section_id` (único); `section_dates` permite fechas
  específicas por sección en vez de generarlas desde `start_date`.
- El monto total se calcula en el backend con `WeeklyPlan#calculate_final_price` /
  `determine_base_price` (aplica precio de sábado y descuento del período).

### Respuesta

```json
{
  "success": true,
  "message": "Transacción iniciada. Complete el pago para finalizar la inscripción",
  "transbank_payment": {
    "url": "https://webpay3gint.transbank.cl/webpayserver/initTransaction",
    "token": "01ab89c...",
    "full_url": "https://webpay3gint.transbank.cl/webpayserver/initTransaction?token_ws=01ab89c...",
    "buy_order": "PEND-1733452718",
    "amount": 50000,
    "transaction_id": 42
  }
}
```

En error responde `{ "success": false, "error": "..." }` con status 500.

**Importante:** la respuesta **no** incluye `enrollment_id` ni datos del estudiante,
porque la inscripción todavía no existe en este punto. El frontend solo debe redirigir a
`transbank_payment.full_url`.

### Ejemplo de integración (SPA)

```javascript
async function createEnrollmentAndPay(enrollments) {
  const response = await fetch(`${BACKEND_URL}/api/v1/enrollments`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify({ enrollments }) // ← array bajo la clave "enrollments"
  });

  const data = await response.json();
  if (data.success) {
    window.location.href = data.transbank_payment.full_url;
  } else {
    console.error(data.error);
  }
}
```

## Flujo 2 — Pago de una inscripción existente

`POST /students/payments/pay_enrollment_fee/:enrollment_id`
(`Students::PaymentsController`). La inscripción ya existe; este endpoint solo inicia el
cobro de su arancel.

- **Requiere usuario autenticado** (`authenticate_user!`). El estudiante es
  `current_user.student` — ya **no** se acepta un `student_id` por parámetro.
- Valida `enrollment.enrollment_fee_paid?`; si ya está pagada responde 422.
- Crea la `TransbankTransaction` (con `enrollment` asociado, `buy_order`
  `ENR{id}-FEE-{timestamp}`), inicia la transacción y responde JSON con
  `{ url, token, full_url, buy_order, amount }`.
- El callback es el mismo que el del flujo 1.

`GET /students/payments` lista las inscripciones del estudiante autenticado y las
matrículas pendientes (`enrollments.reject(&:enrollment_fee_paid?)`).

> `enrollment_fee_paid?` es un **método derivado** (consulta los `payments` de tipo
> `enrollment_fee`); **no** existe una columna `enrollment_fee_paid` que se "marque".

## Modelos

### TransbankTransaction
- `token`: token único de Transbank.
- `buy_order`: orden de compra (`PEND-...` para pagos de inscripción nueva; `ENR...-FEE-...`
  para inscripción existente).
- `amount`, `status` (`pending` / `authorized` / `failed` / `nullified`).
- `enrollment_id`: puede ser `nil` mientras está `pending` en el flujo 1.
- `enrollment_data`: JSON con los datos de la(s) inscripción(es) a crear tras el pago.
- `authorization_code`, `card_number`, `response_code`, `raw_response`, `error_message`.
- `mark_as_authorized!(response)`: crea inscripción(es) + Payment(s) y marca `authorized`
  (todo dentro de una transacción de BD). Soporta múltiples inscripciones.

### Payment
- Se crea automáticamente cuando la `TransbankTransaction` se autoriza.
- `reference_number` = `authorization_code` de Transbank; `notes` incluye el `buy_order`.
- `status: completed` al crearse desde el callback.

## Configuración

### Credenciales (`config/initializers/transbank.rb`)

`TransbankConfig.use_production?` es `true` **solo** si `Rails.env.production?` **y**
ambas envs (`TRANSBANK_COMMERCE_CODE`, `TRANSBANK_API_KEY`) están presentes. Si no, cae
a las credenciales de **integración**:

- **Commerce Code**: `597055555532`
- **API Key**: `579B532A7440BB0C9079DED94D31EA1615BACEB56610332264630D42D0A36B1C`

### Variables de entorno

| Variable | Uso | Obligatoria |
|----------|-----|-------------|
| `BACKEND_URL` | URL pública del backend para el `return_url` de Transbank (`/api/v1/enrollments`). Si falta, el endpoint **lanza error** en vez de usar un valor por defecto. | Sí (para el flujo 1) |
| `FRONTEND_URL` | A dónde redirige el callback tras el pago (`/payment/success` o `/payment/failure`). Default en dev: `http://localhost:5173`. | En prod |
| `TRANSBANK_COMMERCE_CODE` / `TRANSBANK_API_KEY` | Credenciales de producción. | En prod |

> En dev, `BACKEND_URL` debe apuntar a una URL alcanzable por Transbank (p. ej. un túnel
> de Cloudflare). Ver el host comentado en `config/environments/development.rb`.

### Tarjetas de prueba (ambiente de integración)

**Débito:** `4051 8856 0044 6623` · CVV `123` · fecha futura · RUT `11.111.111-1` · clave `123`
**Crédito:** Redcompra `4051 8842 3993 7763` · Mastercard `5186 0595 3805 6286` · Visa `4051 8856 0044 6623`

### CORS (`config/initializers/cors.rb`)

No usa `origins '*'`. Hay una allowlist explícita con `credentials: true`:

```ruby
allowed_origins = [
  'http://localhost:3000',   # CRA / Next.js
  'http://localhost:5173',   # Vite
  'http://localhost:4200',   # Angular
  'http://localhost:8080',   # Vue CLI
  'https://www.gustarte.cl', # Producción
  'https://gustarte.cl',
  ENV['FRONTEND_URL']
].compact
```

Para agregar un dominio de producción, añádelo a esa lista o setea `FRONTEND_URL`.

## Rutas

- `POST /api/v1/enrollments` — inicia pago de inscripción nueva (flujo 1).
- `GET  /students/payments` — inscripciones y matrículas pendientes del estudiante (autenticado).
- `POST /students/payments/pay_enrollment_fee/:enrollment_id` — pago de inscripción existente (flujo 2).
- `GET/POST /transbank/callback` — callback de Transbank.
- `GET /transbank/result/success` · `GET /transbank/result/failure` — páginas de resultado
  (el callback normalmente redirige a la SPA en `FRONTEND_URL`).

## Seguridad

- **CSRF**: `TransbankController#callback` y `Api::V1::BaseController` tienen
  `skip_before_action :verify_authenticity_token` (llamadas server-to-server / API).
- **Autenticación**: `Students::PaymentsController` exige `authenticate_user!` y usa
  `current_user.student`. `Api::V1::EnrollmentsController` es público (no autentica) — el
  cobro real ocurre en Transbank.
- **Token único** por transacción, validado en el callback.
- **Cancelación**: el callback maneja el caso `TBK_ORDEN_COMPRA` sin `token_ws` (usuario
  canceló) marcando la transacción como `failed`.

## Panel de administración

`/admin/transbank_transactions` (solo lectura) muestra estadísticas (total / autorizadas
/ pendientes / fallidas / monto autorizado), filtros por estado, tabla con estudiante,
monto, buy order, estado, código de autorización y últimos 4 dígitos; y una vista de
detalle con la respuesta cruda de Transbank y el enlace al `Payment` generado.

## Troubleshooting

- **"Token no recibido"** → Transbank no está redirigiendo con `token_ws`; revisar el
  `return_url` (`BACKEND_URL`).
- **"Transacción no encontrada"** → el token no existe en la BD; la transacción no se
  creó bien antes de redirigir.
- **Pago exitoso pero no se crea el Payment / la inscripción** → revisar logs; verificar
  que `mark_as_authorized!` corrió sin error y que `enrollment_data` era válido para
  `EnrollmentCreator`.
- **`KeyError: key not found: "BACKEND_URL"`** al iniciar un pago desde la SPA → falta
  definir `BACKEND_URL`.

## Próximas mejoras

- [ ] Notificación por email al estudiante tras el pago.
- [ ] Comprobante de pago en PDF.
- [x] Panel de administración de transacciones.
- [ ] Anulación / refund de pagos.
- [ ] Expiración automática de transacciones `pending` antiguas.

## Referencias

- [Webpay Plus](https://www.transbankdevelopers.cl/producto/webpay)
- [SDK Ruby](https://github.com/TransbankDevelopers/transbank-sdk-ruby)
- [Cómo empezar](https://www.transbankdevelopers.cl/documentacion/como_empezar)
