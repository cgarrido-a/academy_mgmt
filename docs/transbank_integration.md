# Integración con Transbank Webpay Plus

Este documento describe cómo funciona la integración con Transbank Webpay Plus para pagos online.

## Descripción General

El sistema permite a los estudiantes pagar sus matrículas y cuotas a través de Transbank Webpay Plus, procesando automáticamente los pagos y actualizando los estados correspondientes.

## Flujo de Pago

### Flujo Principal: Inscripción + Pago de Matrícula

```
1. Estudiante → Completa formulario de inscripción en el frontend
2. Frontend → POST /api/v1/enrollments (crea enrollment + inicia pago)
3. Backend → Crea Student (si no existe)
4. Backend → Crea Enrollment
5. Backend → Crea TransbankTransaction (status: pending)
6. Backend → Inicia transacción con Transbank API
7. Backend → Retorna JSON con datos del enrollment + URL de Transbank
8. Frontend → Redirige al estudiante a Transbank (window.location.href)
9. Estudiante → Completa el pago en Transbank
10. Transbank → Redirige al callback /transbank/callback (en backend)
11. Backend → Confirma la transacción con Transbank
12. Backend → Si aprobada:
   - Crea registro Payment para la matrícula
   - Actualiza TransbankTransaction (status: authorized)
   - Marca enrollment_fee_paid = true
13. Backend → Redirige a página de éxito/fallo (puede ser en frontend)
```

### Flujo Alternativo: Pago de Cuotas

```
1. Estudiante → Ve sus cuotas pendientes en el frontend
2. Estudiante → Hace clic en "Pagar cuota"
3. Frontend → POST /student/payments/pay_installment/:enrollment_id/:installment_id
4. Backend → Crea TransbankTransaction (status: pending)
5. Backend → Inicia transacción con Transbank API
6. Backend → Retorna JSON con URL de Transbank
7. Frontend → Redirige al estudiante a Transbank (window.location.href)
8. Estudiante → Completa el pago en Transbank
9. Transbank → Redirige al callback /transbank/callback (en backend)
10. Backend → Confirma la transacción con Transbank
11. Backend → Si aprobada:
   - Crea registro Payment
   - Actualiza TransbankTransaction (status: authorized)
   - Actualiza estado de Installment
12. Backend → Redirige a página de éxito/fallo (puede ser en frontend)
```

### Con Vistas de Rails (Monolito)

```
1. Estudiante → Ve sus pagos pendientes en /student/payments
2. Estudiante → Hace clic en "Pagar con Webpay"
3. Sistema → Crea TransbankTransaction (status: pending)
4. Sistema → Inicia transacción con Transbank API
5. Estudiante → Redirigido a Transbank para ingresar datos de tarjeta
6. Estudiante → Completa el pago en Transbank
7. Transbank → Redirige al callback /transbank/callback
8. Sistema → Confirma la transacción con Transbank
9. Sistema → Si aprobada:
   - Crea registro Payment
   - Actualiza TransbankTransaction (status: authorized)
   - Actualiza estado de Installment (si aplica)
10. Estudiante → Redirigido a página de éxito/fallo
```

## Modelos

### TransbankTransaction
Almacena información de cada intento de pago:
- `token`: Token único de Transbank
- `buy_order`: Orden de compra generada
- `amount`: Monto de la transacción
- `status`: pending, authorized, failed, nullified
- `authorization_code`: Código de autorización de Transbank (si aprobada)
- `raw_response`: Respuesta completa de Transbank

### Payment (actualizado)
- Se crea automáticamente cuando TransbankTransaction es autorizada
- `reference_number` contiene el `authorization_code` de Transbank
- `notes` incluye el `buy_order` para trazabilidad

## Configuración

### Ambiente de Integración (Desarrollo/Testing)

El ambiente de integración usa credenciales de prueba de Transbank:
- **Commerce Code**: 597055555532
- **API Key**: 579B532A7440BB0C9079DED94D31EA1615BACEB56610332264630D42D0A36B1C

Estas credenciales están configuradas automáticamente en `config/initializers/transbank.rb`.

### Tarjetas de Prueba

Para testing, usa estas tarjetas de Transbank:

**Tarjetas de Débito:**
- Número: 4051 8856 0044 6623
- CVV: 123
- Fecha: cualquier fecha futura
- RUT: 11.111.111-1
- Clave: 123

**Tarjetas de Crédito:**
- Redcompra: 4051 8842 3993 7763
- Mastercard: 5186 0595 3805 6286
- Visa: 4051 8856 0044 6623

### Ambiente de Producción

Para producción, necesitas:

1. **Registrarte en Transbank Developers**
   - Ir a https://www.transbankdevelopers.cl/
   - Crear una cuenta
   - Solicitar credenciales de producción

2. **Configurar Variables de Entorno**
   ```bash
   export TRANSBANK_COMMERCE_CODE=tu_codigo_de_comercio
   export TRANSBANK_API_KEY=tu_api_key
   ```

3. **Verificar Configuración**
   El initializer detectará automáticamente el ambiente de producción y usará las credenciales desde las variables de entorno.

## Rutas

### API de Inscripción (Frontend Separado)
- `POST /api/v1/enrollments` - Crear inscripción e iniciar pago de matrícula

### Para Estudiantes
- `GET /student/payments` - Ver pagos pendientes
- `POST /student/payments/pay_enrollment_fee/:enrollment_id` - Iniciar pago de matrícula (si ya existe enrollment)
- `POST /student/payments/pay_installment/:enrollment_id/:installment_id` - Iniciar pago de cuota

### Callbacks de Transbank
- `GET/POST /transbank/callback` - Callback de Transbank (recibe confirmación)
- `GET /transbank/result/success` - Página de éxito
- `GET /transbank/result/failure` - Página de fallo

## Integración con Frontend Separado

### Respuesta JSON de las APIs

Ambos endpoints (`pay_enrollment_fee` y `pay_installment`) retornan JSON:

**Respuesta Exitosa (200 OK):**
```json
{
  "url": "https://webpay3gint.transbank.cl/webpayserver/initTransaction",
  "token": "01ab89c...",
  "full_url": "https://webpay3gint.transbank.cl/webpayserver/initTransaction?token_ws=01ab89c...",
  "buy_order": "ENR-123-20251117",
  "amount": 50000,
  "installment_id": 456  // Solo en pay_installment
}
```

**Respuesta de Error (422 o 500):**
```json
{
  "error": "La matrícula ya ha sido pagada."
}
```

### Ejemplo de Integración Frontend

#### 1. Crear Inscripción e Iniciar Pago (Flujo Principal)

**JavaScript / Fetch API:**

```javascript
// Crear enrollment y obtener URL de pago
async function createEnrollmentAndPay(enrollmentData) {
  try {
    const response = await fetch('/api/v1/enrollments', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      credentials: 'include',
      body: JSON.stringify({
        enrollment: {
          name: enrollmentData.name,
          email: enrollmentData.email,
          section_ids: enrollmentData.section_ids,
          payment_plan_id: enrollmentData.payment_plan_id,
          payment_method_id: 2, // Webpay Plus
          enrollment_amount: enrollmentData.enrollment_amount,
          total_tuition_fee: enrollmentData.total_tuition_fee,
          instalments_number: enrollmentData.instalments_number
        }
      })
    });

    const data = await response.json();

    if (data.success && data.transbank_payment) {
      // Guardar enrollment_id por si se necesita después
      localStorage.setItem('enrollment_id', data.enrollment_id);

      // Redirigir a Transbank para pagar
      window.location.href = data.transbank_payment.full_url;
    } else {
      // Mostrar errores
      console.error('Errores:', data.errors);
      alert('Error al crear la inscripción');
    }
  } catch (error) {
    console.error('Error:', error);
    alert('Error al conectar con el servidor');
  }
}

// Ejemplo de uso
const enrollmentData = {
  name: 'Juan Pérez',
  email: 'juan@example.com',
  section_ids: [1, 2], // IDs de las secciones/cursos
  payment_plan_id: 1,
  enrollment_amount: 50000,
  total_tuition_fee: 450000,
  instalments_number: 9
};

createEnrollmentAndPay(enrollmentData);
```

**React Example:**

```jsx
import { useState } from 'react';

function EnrollmentForm() {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    section_ids: [],
    payment_plan_id: '',
    enrollment_amount: 0,
    total_tuition_fee: 0,
    instalments_number: 0
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const response = await fetch('/api/v1/enrollments', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        credentials: 'include',
        body: JSON.stringify({ enrollment: formData })
      });

      const data = await response.json();

      if (data.success && data.transbank_payment) {
        // Guardar enrollment_id
        localStorage.setItem('enrollment_id', data.enrollment_id);

        // Redirigir a Transbank
        window.location.href = data.transbank_payment.full_url;
      } else {
        setError(data.errors || 'Error al crear la inscripción');
      }
    } catch (err) {
      setError('Error al procesar la inscripción');
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="text"
        placeholder="Nombre completo"
        value={formData.name}
        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
        required
      />
      <input
        type="email"
        placeholder="Email"
        value={formData.email}
        onChange={(e) => setFormData({ ...formData, email: e.target.value })}
        required
      />
      {/* Más campos del formulario... */}

      <button type="submit" disabled={loading}>
        {loading ? 'Procesando...' : 'Inscribirse y Pagar'}
      </button>

      {error && <div className="error">{JSON.stringify(error)}</div>}
    </form>
  );
}
```

**Respuesta del Backend:**

```json
{
  "success": true,
  "message": "Enrollment created successfully",
  "enrollment_id": 123,
  "data": {
    "id": 123,
    "student": {
      "id": 45,
      "name": "Juan Pérez",
      "email": "juan@example.com"
    },
    "sections": [...],
    "payment_plan": {...},
    "enrollment_amount": 50000,
    "tuition_fee": {...}
  },
  "transbank_payment": {
    "url": "https://webpay3gint.transbank.cl/webpayserver/initTransaction",
    "token": "01ab89c...",
    "full_url": "https://webpay3gint.transbank.cl/webpayserver/initTransaction?token_ws=01ab89c...",
    "buy_order": "ENR-123-20251117",
    "amount": 50000
  }
}
```

#### 2. Pagar Cuotas (Flujo Alternativo)

**JavaScript / Fetch API**

```javascript
// Pagar matrícula
async function payEnrollmentFee(enrollmentId) {
  try {
    const response = await fetch(`/student/payments/pay_enrollment_fee/${enrollmentId}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        // Agregar token de autenticación si lo usas
        // 'Authorization': `Bearer ${token}`
      },
      credentials: 'include' // Importante para cookies/sesiones
    });

    const data = await response.json();

    if (response.ok) {
      // Redirigir al estudiante a Transbank
      window.location.href = data.full_url;
    } else {
      // Mostrar error al usuario
      alert(data.error);
    }
  } catch (error) {
    console.error('Error al iniciar pago:', error);
    alert('Error al conectar con el servidor');
  }
}

// Pagar cuota
async function payInstallment(enrollmentId, installmentId) {
  try {
    const response = await fetch(
      `/student/payments/pay_installment/${enrollmentId}/${installmentId}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include'
      }
    );

    const data = await response.json();

    if (response.ok) {
      window.location.href = data.full_url;
    } else {
      alert(data.error);
    }
  } catch (error) {
    console.error('Error:', error);
  }
}
```

#### React Example

```jsx
import { useState } from 'react';

function PaymentButton({ enrollmentId, installmentId = null }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handlePayment = async () => {
    setLoading(true);
    setError(null);

    try {
      const endpoint = installmentId
        ? `/student/payments/pay_installment/${enrollmentId}/${installmentId}`
        : `/student/payments/pay_enrollment_fee/${enrollmentId}`;

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include'
      });

      const data = await response.json();

      if (response.ok) {
        // Redirigir a Transbank
        window.location.href = data.full_url;
      } else {
        setError(data.error);
      }
    } catch (err) {
      setError('Error al procesar el pago');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <button onClick={handlePayment} disabled={loading}>
        {loading ? 'Procesando...' : 'Pagar con Webpay'}
      </button>
      {error && <p style={{ color: 'red' }}>{error}</p>}
    </div>
  );
}
```

### Configuración CORS

Para que el frontend pueda comunicarse con el backend desde otro dominio:

**Ya está configurado en `config/initializers/cors.rb`:**
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*' # En desarrollo
    # En producción: origins 'https://tu-frontend.com'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
```

**Para producción**, cambia `origins '*'` por el dominio específico de tu frontend:
```ruby
origins 'https://tu-frontend.com', 'https://www.tu-frontend.com'
```

## Seguridad

### CSRF Protection
El callback de Transbank tiene `skip_before_action :verify_authenticity_token` porque Transbank hace la llamada desde su servidor.

### Validación de Token
Cada transacción tiene un token único que se valida en el callback.

### Timeout
Las transacciones pendientes por más de 30 minutos pueden considerarse expiradas.

## Actualización Automática de Estados

Cuando un pago es autorizado:

1. **TransbankTransaction** → `status: 'authorized'`
2. **Payment** → Nuevo registro creado
3. **Installment** → Se llama `update_payment_status!` que:
   - Calcula `total_paid` sumando todos los payments
   - Si `total_paid >= amount` → `status: 'paid'`
   - Si vencida y no pagada → `status: 'overdue'`
   - Si no → `status: 'pending'`

## Testing

### Probar Pago Exitoso
1. Ir a `/student/payments?student_id=1`
2. Clic en "Pagar con Webpay"
3. Usar tarjeta de prueba
4. Verificar redirección a página de éxito
5. Verificar que se creó Payment y se actualizó status

### Probar Pago Rechazado
1. Usar una tarjeta inválida o cancelar en Transbank
2. Verificar redirección a página de fallo
3. Verificar que TransbankTransaction quedó con `status: 'failed'`

## Monitoreo

### Ver Transacciones en Admin
Agrega al panel de administración:
```ruby
# En admin/payments_controller.rb
def index
  @payments = Payment.includes(:enrollment).order(created_at: :desc)
  @transbank_transactions = TransbankTransaction.includes(:enrollment).order(created_at: :desc).limit(50)
end
```

### Logs
Todas las transacciones se registran en `Rails.logger`:
- Inicio de transacción
- Callback recibido
- Resultado (éxito/fallo)
- Errores

## Troubleshooting

### Error: "Token no recibido"
- Verificar que Transbank esté redirigiendo correctamente
- Revisar URL de callback en configuración

### Error: "Transacción no encontrada"
- El token no existe en la base de datos
- Verificar que se creó correctamente antes de redirigir

### Pago exitoso pero no se crea Payment
- Revisar logs del servidor
- Verificar que `mark_as_authorized!` se ejecutó sin errores
- Revisar transacciones en la base de datos

## Próximas Mejoras

- [ ] Agregar notificaciones por email al estudiante
- [ ] Agregar comprobante de pago en PDF
- [x] Agregar panel de administración para ver todas las transacciones
- [ ] Agregar anulación de pagos (refund)
- [ ] Agregar webhooks para notificaciones asíncronas
- [ ] Agregar retry automático para transacciones fallidas

## Panel de Administración

El sistema incluye un panel completo en `/admin/transbank_transactions` con:

### Características del Panel:
- ✅ **Estadísticas en tiempo real**:
  - Total de transacciones
  - Transacciones autorizadas
  - Transacciones pendientes
  - Transacciones fallidas
  - Monto total autorizado

- ✅ **Filtros por estado**:
  - Todas las transacciones
  - Solo autorizadas
  - Solo pendientes
  - Solo fallidas

- ✅ **Tabla completa con**:
  - ID y fecha de transacción
  - Estudiante
  - Tipo de pago (matrícula/cuota)
  - Monto
  - Buy order
  - Estado
  - Código de autorización
  - Últimos 4 dígitos de tarjeta

- ✅ **Vista detallada de cada transacción**:
  - Información completa de la transacción
  - Detalles de autorización (si aplica)
  - Información del estudiante
  - Información de la cuota (si aplica)
  - Respuesta completa de Transbank (JSON)
  - Enlace al payment generado (si fue autorizada)
  - Mensaje de error (si falló)

## Referencias

- [Documentación Transbank Webpay Plus](https://www.transbankdevelopers.cl/producto/webpay)
- [SDK Ruby Transbank](https://github.com/TransbankDevelopers/transbank-sdk-ruby)
- [Ejemplos de Integración](https://www.transbankdevelopers.cl/documentacion/como_empezar)
