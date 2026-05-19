# Cambios en el sistema – Mayo 2026

Esta es la presentación de las mejoras realizadas al sistema de gestión de la academia. Cada bloque explica qué se mejoró, para quién y qué problema resuelve.

---

## Resumen general

En esta ronda de trabajo se rediseñó la mayoría de las pantallas que usan a diario administradores y docentes, se incorporó un sistema completo para gestionar **recuperaciones de clases**, se redefinió el **cálculo de pago a docentes** y se agregaron mecanismos para que cada usuario administre su propio perfil. El foco fue hacer el sistema más fácil de leer, más rápido de operar y más fiel a la realidad de la academia.

---

## 1. Dashboard del docente

### Antes
El docente entraba a su panel y veía un calendario donde todas las clases aparecían iguales: una mancha azul. No se distinguía entre clases ya dictadas, clases pendientes de marcar asistencia, ni las que vienen a futuro. Costaba saber a qué prestar atención primero.

### Ahora
- Cada clase del calendario tiene **color según su estado**:
  - **Verde**: asistencia ya tomada y completa.
  - **Naranja**: clase ya dictada pero con alumnos sin marcar (el docente sabe que debe completar).
  - **Azul**: clase que viene a futuro.
  - **Amarillo**: el día de hoy (visualmente destacado con una banda en la parte superior).
- Cada clase muestra **cuántos alumnos hay y cuántos ya fueron marcados** (ej.: "3/8 sin marcar").
- Los **fines de semana** se distinguen visualmente de los días hábiles.
- Se agregó una **leyenda** explicando qué significa cada color.

### Qué gana el docente
De un vistazo sabe qué clases requieren su atención inmediata (las naranjas), sin tener que entrar a cada una.

---

## 2. Dashboard del administrador

### Antes
Mostraba un bloque de "Inscripciones Recientes" que ocupaba mucho espacio sin agregar información práctica. La tabla de actividad docente tenía una columna "Total registros" que confundía más que ayudaba (era la multiplicación de alumnos × clases del mes).

### Ahora
- Se eliminó la sección de inscripciones recientes (se accede igual desde el listado completo).
- Se eliminó la columna confusa "Total registros". Las columnas que quedan muestran datos directamente accionables: secciones, clases dictadas, alumnos, presentes, ausentes y porcentaje de asistencia.

### Qué gana el admin
Una vista más limpia que se enfoca en métricas relevantes.

---

## 3. Gestión de secciones

### Antes
El listado de secciones era una tabla básica con texto plano. No había forma de filtrar por curso, los días aparecían como texto, y la información de cupos era poco visual.

La pantalla de detalle de cada sección era funcional pero "fría": un panel con los datos como un formulario, una lista de alumnos genérica, un toggle pequeño para marcar asistencia.

### Ahora
**En el listado:**
- **Botones de filtro por curso** arriba de la tabla. Click en "Yoga" y solo se ven las secciones de yoga.
- **Día de la semana como etiqueta de color** (cada día con su tono distintivo).
- **Barra de ocupación visual** (verde / naranja / rojo según qué tan llena esté la sección).
- **Avatar del profesor** con sus iniciales junto al nombre.
- Acciones compactas como íconos (ver / editar / eliminar) en vez de tres botones grandes.

**En el detalle:**
- **Encabezado compacto** con el curso como protagonista, día, horario, profesor y cupos en chips.
- **Estadísticas del día seleccionado** arriba de la lista de alumnos: presentes, ausentes, pendientes y porcentaje de asistencia. Se actualizan en vivo al marcar.
- **Navegación rápida entre fechas**: una fila de "atajos" con las clases recientes y próximas; flechas para retroceder o avanzar en el tiempo.
- **Botones grandes Presente / Ausente** (verde / rojo) en vez del toggle pequeño que confundía.
- **Historial del alumno**: junto a cada nombre aparece su porcentaje de asistencia histórico en esa sección (ej.: "10/12 (83%)"). Útil para saber rápido quién es regular y quién no.
- **Buscador de alumno por nombre** dentro de la lista.
- **Click en el nombre de un alumno** → abre directamente su inscripción.

### Regla nueva sobre marcado de asistencia
- **Los docentes solo pueden marcar asistencia de hoy en adelante**. Si necesitan corregir una asistencia pasada, deben coordinarlo con el administrador.
- **El administrador puede marcar asistencia de cualquier fecha**.
- Si un docente entra a una fecha pasada, ve la información en modo "solo lectura" con un cartel explicativo.

### Qué gana el equipo
- El admin filtra cursos en segundos sin buscar manualmente.
- El docente toma asistencia más rápido y visualmente.
- Las correcciones pasadas no quedan en manos de cualquiera (más control).

---

## 4. Recuperaciones de clases

### Problema que resuelve
Antes, cuando un alumno faltaba y luego quería "recuperar" la clase otro día, el sistema permitía cambiarle la fecha a su inscripción. Pero al hacerlo, **la falta original desaparecía** del registro: quedaba como si nunca hubiera faltado. Eso impedía llevar estadísticas reales de asistencia y dejaba huecos en el historial.

### Solución
Se agregó un flujo dedicado de **"Asignar recuperatorio"** que:
- **Conserva la falta original** en el registro.
- **Crea una clase nueva** marcada como recuperatorio, vinculada a la falta que recupera.
- **Se ve claramente** quién es alumno regular y quién está como recuperatorio en cada clase (con etiquetas de color).

### Cómo funciona en la práctica
1. Cuando un alumno está marcado como ausente, aparece debajo de su nombre un botón **"🔁 Asignar recuperatorio"**.
2. Al hacer click, se abre un formulario que muestra las **próximas 8 semanas de clases del mismo curso** como tarjetas seleccionables.
3. Cada tarjeta indica cuántos cupos hay disponibles.
4. Las tarjetas que ya están llenas, o donde el alumno ya tiene clase, aparecen deshabilitadas con explicación.
5. Se selecciona la fecha + sección, se puede agregar un motivo opcional, y se confirma.
6. El alumno aparece automáticamente en la lista de esa nueva clase con la etiqueta **"🔁 Recuperatorio"**.
7. En la clase original donde faltó, queda la etiqueta **"↪ Recuperado el DD/MM"** para que se vea que ya tuvo solución.

### Permisos
- **El docente** puede asignar recuperatorios en sus propias secciones.
- **Si el alumno quiere recuperar en una sección de otro docente**, el docente original ve la opción pero **debe coordinarlo con el administrador**, quien es el único que puede asignar entre secciones de distintos profesores.
- Las secciones de otros docentes aparecen visibles pero **deshabilitadas con un candado**, para que el docente pueda al menos informarle al alumno qué alternativas existen.

### Reglas básicas que aplica el sistema
- Solo se puede asignar un recuperatorio a una falta confirmada.
- Una misma falta solo puede tener un recuperatorio.
- **No se puede recuperar un recuperatorio**: si el alumno también falta a la clase de reposición, esa clase del plan se da por perdida. Una falta del plan da derecho a un único intento de recuperación.
- El recuperatorio debe ser en una sección del mismo curso.
- La fecha del recuperatorio debe ser futura y respetar el cupo de la sala.
- **La fecha del recuperatorio debe estar dentro del período del plan contratado** (entre la primera y la última clase del alumno). El docente está limitado a esta regla; **el administrador puede asignar recuperatorios fuera del período** como excepciones puntuales.
- **No se puede recuperar en una fecha en que el alumno ya tiene clase agendada del plan**. Por ejemplo, si un alumno contrató todos los lunes y faltó a uno, los otros lunes que ya están programados aparecen visiblemente marcados como "✓ Agendada" y no se pueden seleccionar. Evita doble agenda y le ahorra al admin tener que recordar la grilla completa del alumno.

### Motivo de la recuperación
Cuando se asigna un recuperatorio se puede dejar un **motivo opcional** (por ejemplo "alumno enfermo", "viaje familiar"). Ese motivo ahora se muestra en todas las vistas donde aparece la clase: el detalle de la inscripción, la lista de alumnos del día, y como tooltip del badge de recuperatorio. Útil para que el siguiente que revise (profesor o admin) entienda por qué fue necesario.

### Qué gana la academia
- Trazabilidad real: se sabe cuántas faltas hubo, cuántas se recuperaron y dónde.
- Justicia con el docente: la asistencia al recuperatorio queda registrada con quien efectivamente la dictó.
- El alumno tiene constancia formal de que recuperó su clase.

---

## 5. Inscripciones

### Antes
El listado de inscripciones era una tabla larga sin forma de buscar a un alumno específico. La pantalla de detalle mostraba la información en un formato tipo formulario, no permitía ver el estado de asistencia general ni cuánto debe el alumno.

### Ahora
**Listado:**
- **Buscador** por nombre o email del alumno.
- Contador de resultados en el título.
- Estado vacío personalizado cuando no hay coincidencias.

**Detalle:**
- **Ficha del alumno** con dos columnas: datos personales a la izquierda, datos del contrato a la derecha (curso, plan, meses contratados, vigencia, profesores, método de pago, matrícula, arancel).
- **Total contratado y saldo pendiente** destacados al pie de la ficha.
- **Historial de pagos** ahora aparece antes que la lista de clases (orden más lógico para el admin).
- **Clases agrupadas por mes**, con un resumen por mes (cuántas asistió, cuántas faltó, cuántas pendientes, cuántos recuperatorios).
- Cada clase muestra: fecha, día, sección (linkeable), profesor, tipo (regular o recuperatorio), estado de asistencia, y acciones contextuales.
- **Porcentaje de asistencia al plan** en la cabecera (con la fórmula correcta que considera los recuperatorios).
- **Las clases ya marcadas con asistencia no se pueden editar** (para reubicar a un alumno que ya tiene asistencia tomada, hay que usar el flujo de recuperatorio).

### Qué gana el admin
Visión completa del alumno en una sola pantalla: contrato, dinero, asistencia, historial. Sin saltar entre pantallas.

---

## 6. Perfil de alumno

### Antes
Al entrar al detalle de un alumno desde el panel de usuarios, solo se veía su nombre, email y una lista plana de sus inscripciones.

### Ahora
Para alumnos, la vista incluye:
- **Tarjetas de resumen**: porcentaje de asistencia agregado (todas las inscripciones), cantidad de inscripciones, total de recuperatorios, saldo pendiente.
- **Lista de inscripciones** como tarjetas: cada una con su curso, plan, método de pago, fecha de inscripción, porcentaje de asistencia y estado de pago (al día / debe).
- **Click directo** a cualquier inscripción para ver detalle completo.

### Qué gana el admin
Antes de cualquier conversación con un alumno o tutor, tiene a la mano la foto completa de su situación.

---

## 7. Pago a docentes

### Antes
La fórmula para calcular cuánto cobra un docente tenía varios problemas:
- Usaba el arancel del alumno dividido entre TODAS sus clases inscritas. Si el alumno tenía un recuperatorio, las cuentas se "diluían" y el docente cobraba menos por cada clase.
- Los **descuentos por contratar varios meses** (3 / 6 / 12 meses) terminaban afectando al docente: si el alumno pagó menos por hacer un contrato anual, el docente también cobraba menos. Esto no era justo.
- Al entrar al panel mostraba por defecto el último mes con datos, que podía ser un mes futuro (por datos cargados a futuro).

### Ahora
**Nueva fórmula:**
- Por cada clase asistida del docente en el mes:
  - Se calcula el **precio por clase a partir del plan del alumno**: `precio mensual del plan ÷ clases mensuales del plan` (con tarifa especial para sábados si corresponde).
  - El docente cobra el **42,5%** de ese precio.
- Los descuentos que el alumno consiguió por pagar varios meses ya **no afectan al docente** (los absorbe la academia).
- Los **recuperatorios cuentan igual** que las clases regulares: el docente que efectivamente dictó la clase cobra por ella.
- Las **faltas no se pagan** (consistente con la idea de pagar por clase asistida).

**En la pantalla:**
- Cada celda monetaria muestra el valor bruto (lo que pagó el alumno) y abajo en verde, lo que **le corresponde al docente** (con el 42,5% aplicado). Útil para auditar la trazabilidad completa.
- Al entrar a la sección, por defecto se muestra **el mes actual**, no un mes futuro.
- Cuando un alumno tiene asistencias mezcla entre semana y sábado con precios distintos, se indica "varía" en vez de un promedio engañoso.

### Qué gana la academia
- Cuentas más limpias y justas con los docentes.
- Los descuentos comerciales no salen del bolsillo del profesor.

---

## 8. Perfil personal de usuario

### Antes
No existía pantalla para que un usuario actualizara sus propios datos. Si un docente cambiaba de teléfono o quería cambiar su contraseña, dependía del administrador.

### Ahora
- En la barra superior, donde antes aparecía el email, ahora hay un **menú desplegable** con el nombre del usuario y dos opciones: **"Mi perfil"** y **"Cerrar sesión"**.
- "Mi perfil" abre una pantalla donde el usuario puede actualizar:
  - **Nombre completo**.
  - **Teléfono**.
  - **Contraseña** (con confirmación de la contraseña actual por seguridad).
- El **email no se puede cambiar** desde aquí (queda como dato administrativo). Si alguien necesita cambiarlo, lo gestiona el admin.
- Se muestra también el **rol** del usuario (Administrador / Profesor / Estudiante) con etiqueta de color.

### Qué gana el usuario
Autonomía para mantener sus datos al día sin depender del admin.

---

## Resumen rápido de impacto

| Área | Beneficio principal |
|---|---|
| Calendario del docente | Saber a qué clase atender primero, de un vistazo. |
| Listado de secciones | Filtrar por curso y ver ocupación real al instante. |
| Detalle de sección | Tomar asistencia más rápido, con contexto del alumno. |
| Recuperatorios | Trazabilidad completa de faltas y reposiciones. |
| Inscripciones | Vista 360° del alumno: contrato + pagos + asistencia. |
| Perfil del alumno | Resumen consolidado antes de cualquier conversación. |
| Pago a docentes | Cálculo justo, sin descuentos que afecten al profesor. |
| Perfil de usuario | Cada uno gestiona sus propios datos. |

---

## Lo que viene

Algunos temas que quedaron identificados pero aún no se abordaron:

- Definir reglas de **cantidad máxima** y **distribución temporal** de recuperaciones por plan (cuántas se permiten al mes, separación mínima entre ellas, etc.). Se evaluaron opciones pero se decidió no incorporar esas reglas estrictas por ahora — la academia las gestiona caso a caso. La única regla activa hoy es que el recuperatorio quede dentro del período del plan, con excepción del administrador.
- Posible vista pública del estudiante (hoy los alumnos solo acceden a sus pagos).
- Posible reporte exportable de pagos a docentes por período.

Cualquier ajuste o nueva funcionalidad puede priorizarse en próximas iteraciones.
