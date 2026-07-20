# Suspende una sesión de clase (todas las EnrollmentSection de una sección en una
# fecha) y reprograma cada una al FINAL del plan de su alumno: la primera fecha
# semanal de esa misma sección, con cupo, posterior a la última clase del alumno.
#
# La clase NO se pierde ni se marca como falta: solo se mueve su fecha (queda
# pendiente en la nueva fecha). Deja un registro ClassSuspension como historial y
# linkea cada clase movida a él. Pensado para invocarse solo desde el panel admin.
class SessionSuspender
  MAX_WEEKS_AHEAD = 104 # tope de seguridad (~2 años) para el bucle de búsqueda de cupo

  Result = Struct.new(:suspension, :moved, :skipped, keyword_init: true)

  def initialize(section:, date:, reason:, admin_user:)
    @section = section
    @date = date.is_a?(Date) ? date : Date.parse(date.to_s)
    @reason = reason
    @admin_user = admin_user
  end

  def call
    cohort = @section.enrollment_sections
                     .where(date: @date)
                     .includes(enrollment: { student: :user })
    moved = []
    skipped = []

    ActiveRecord::Base.transaction do
      suspension = ClassSuspension.create!(
        section: @section,
        original_date: @date,
        reason: @reason,
        created_by: @admin_user,
        affected_count: 0
      )

      cohort.each do |es|
        # Una sesión suspendida no debería tener asistencia tomada; si la tiene, no la tocamos.
        unless es.attended.nil?
          skipped << { enrollment_section: es, reason: 'asistencia ya marcada' }
          next
        end

        target = target_date_for(es.enrollment)
        if target.nil?
          skipped << { enrollment_section: es, reason: 'sin cupo disponible' }
          next
        end

        es.skip_period_rule = true if es.makeup?
        es.update!(date: target, class_suspension: suspension)
        moved << es
      end

      suspension.update!(affected_count: moved.size)
      Result.new(suspension: suspension, moved: moved, skipped: skipped)
    end
  end

  # Fecha destino = primera fecha semanal de la sección posterior a la última clase
  # regular del enrollment y con cupo disponible. Público para que el controller
  # pueda mostrar el preview sin persistir. Devuelve nil si no encuentra cupo.
  def target_date_for(enrollment)
    _start, contract_end = EnrollmentSection.contract_window_for(enrollment)
    base = contract_end || @date
    candidate = base + 7.days
    MAX_WEEKS_AHEAD.times do
      return candidate if @section.has_available_places_for_date?(candidate)

      candidate += 7.days
    end
    nil
  end
end
