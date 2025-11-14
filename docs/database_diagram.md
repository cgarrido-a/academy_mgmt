# Diagrama de Base de Datos - Academy Management System

## Diagrama de Relaciones (ER Diagram)

```mermaid
erDiagram
    User ||--o| Student : "has one"
    User ||--o| Teacher : "has one"
    User ||--o| AdminUser : "has one"
    User ||--o{ Payment : "processes (optional)"

    Student ||--o{ Enrollment : "has many"

    Teacher ||--o{ Section : "teaches many"

    Course ||--o{ Section : "has many"

    Enrollment }o--|| Student : "belongs to"
    Enrollment }o--|| PaymentPlan : "belongs to"
    Enrollment }o--|| PaymentMethod : "belongs to"
    Enrollment ||--o{ EnrollmentSection : "has many"
    Enrollment ||--o{ Payment : "has many"
    Enrollment ||--o| TuitionFee : "has one"

    Section ||--o{ EnrollmentSection : "has many"
    Section }o--|| Course : "belongs to"
    Section }o--|| Teacher : "belongs to"

    EnrollmentSection }o--|| Enrollment : "belongs to"
    EnrollmentSection }o--|| Section : "belongs to"

    TuitionFee }o--|| Enrollment : "belongs to"
    TuitionFee }o--|| PaymentMethod : "belongs to"
    TuitionFee ||--o{ Installment : "has many"

    Installment }o--|| TuitionFee : "belongs to"
    Installment ||--o{ Payment : "has many"

    Payment }o--|| Enrollment : "belongs to"
    Payment }o--o| Installment : "belongs to (optional)"
    Payment }o--|| PaymentMethod : "belongs to"
    Payment }o--o| User : "processed by (optional)"

    PaymentMethod ||--o{ Enrollment : "used in many"
    PaymentMethod ||--o{ TuitionFee : "used in many"
    PaymentMethod ||--o{ Payment : "used in many"

    PaymentPlan ||--o{ Enrollment : "used in many"

    User {
        bigint id PK
        string name
        string email
        string password_digest
        datetime created_at
        datetime updated_at
    }

    Student {
        bigint id PK
        bigint user_id FK
        datetime created_at
        datetime updated_at
    }

    Teacher {
        bigint id PK
        bigint user_id FK
        string profession
        datetime created_at
        datetime updated_at
    }

    AdminUser {
        bigint id PK
        bigint user_id FK
        string admin_type
        datetime created_at
        datetime updated_at
    }

    Course {
        bigint id PK
        string title
        text description
        decimal price
        datetime created_at
        datetime updated_at
    }

    Section {
        bigint id PK
        bigint course_id FK
        bigint teacher_id FK
        date start_date
        date end_date
        string days_of_week
        integer max_students
        datetime created_at
        datetime updated_at
    }

    Enrollment {
        bigint id PK
        bigint student_id FK
        bigint payment_plan_id FK
        bigint payment_method_id FK
        decimal enrollment_amount
        date payment_date
        datetime created_at
        datetime updated_at
    }

    EnrollmentSection {
        bigint id PK
        bigint enrollment_id FK
        bigint section_id FK
        datetime created_at
        datetime updated_at
    }

    PaymentPlan {
        bigint id PK
        string plan
        string description
        integer number_of_classes
        datetime created_at
        datetime updated_at
    }

    PaymentMethod {
        bigint id PK
        string payment_method
        datetime created_at
        datetime updated_at
    }

    TuitionFee {
        bigint id PK
        bigint enrollment_id FK
        bigint payment_method_id FK
        decimal total_tuition_fee
        integer instalments_number
        string billing_period
        datetime created_at
        datetime updated_at
    }

    Installment {
        bigint id PK
        bigint tuition_fee_id FK
        decimal amount
        date due_date
        date payment_date
        string status
        datetime created_at
        datetime updated_at
    }

    Payment {
        bigint id PK
        bigint enrollment_id FK
        string payment_type
        bigint installment_id FK
        decimal amount
        date payment_date
        bigint payment_method_id FK
        string reference_number
        text notes
        bigint processed_by_id FK
        string status
        datetime created_at
        datetime updated_at
    }
```

## Descripción de Modelos

### 👤 Usuarios y Roles
- **User**: Usuario base del sistema
- **Student**: Estudiante (hereda de User)
- **Teacher**: Profesor (hereda de User)
- **AdminUser**: Administrador (hereda de User)

### 📚 Académico
- **Course**: Cursos disponibles
- **Section**: Secciones/horarios de cursos (impartidas por un profesor)

### 📝 Inscripciones
- **Enrollment**: Inscripción de un estudiante
- **EnrollmentSection**: Tabla intermedia (muchos a muchos entre Enrollment y Section)

### 💰 Pagos y Cuotas
- **PaymentPlan**: Planes de pago disponibles
- **PaymentMethod**: Métodos de pago (efectivo, transferencia, etc.)
- **TuitionFee**: Arancel asociado a una inscripción
- **Installment**: Cuotas mensuales del arancel
- **Payment**: Registro de pagos (matrícula y cuotas)

## Relaciones Clave

### Inscripción Multi-Sección
Un estudiante puede inscribirse en múltiples secciones a través de una sola inscripción:
```
Student → Enrollment → EnrollmentSection ← Section
```

### Sistema de Pagos
Los pagos están centralizados en la tabla `Payment`:
- **Pago de Matrícula**: `payment_type = 'enrollment_fee'` (installment_id = NULL)
- **Pago de Cuota**: `payment_type = 'installment'` (con installment_id)

### Cuotas y Aranceles
```
Enrollment → TuitionFee → Installment ← Payment
```

## Notas de Diseño

1. **Separación de Conceptos**:
   - `Enrollment.enrollment_amount`: Monto de matrícula
   - `TuitionFee.total_tuition_fee`: Monto total del arancel (dividido en cuotas)

2. **Pagos Parciales**:
   - Una cuota (`Installment`) puede tener múltiples pagos (`Payment`)
   - Se calcula el total pagado sumando todos los payments asociados

3. **Auditoría**:
   - `Payment.processed_by_id`: Usuario que registró el pago
   - `Payment.reference_number`: Número de transacción bancaria
   - `Payment.notes`: Notas adicionales

4. **Estados**:
   - `Payment.status`: completed, pending, refunded
   - `Installment.status`: pending, paid, overdue (se actualiza automáticamente)
