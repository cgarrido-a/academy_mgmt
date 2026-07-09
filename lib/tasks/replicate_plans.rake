namespace :plans do
  # Replica los planes "plantilla" (los que hoy no tienen curso) a TODOS los cursos,
  # creando una copia de cada plan por curso con su course_id asignado.
  #
  # Seguridad:
  #   - Idempotente: usa find_or_create_by(course_id, plan) — correrla de nuevo no duplica.
  #   - Dry-run por defecto: solo reporta. Para escribir de verdad hay que pasar APPLY=1.
  #   - Todo dentro de una transacción.
  #
  # Uso (en Render shell, RAILS_ENV ya es production):
  #   bin/rails plans:replicate_to_courses            # dry-run: muestra qué haría
  #   APPLY=1 bin/rails plans:replicate_to_courses     # aplica los cambios
  #
  # Opciones (ENV):
  #   EXCLUDE_IDS=16,17   IDs de planes a excluir de las plantillas (default: "16")
  desc "Replica los planes existentes (sin curso) a todos los cursos"
  task replicate_to_courses: :environment do
    apply       = ENV["APPLY"] == "1"
    exclude_ids = (ENV["EXCLUDE_IDS"] || "16").split(",").map { |s| s.strip.to_i }.reject(&:zero?)

    # Atributos que se copian del plan plantilla a cada copia por curso.
    copyable = %w[description price saturday_price enrollment_fee weekly_classes number_of_classes event_type]

    # Plantillas = definiciones de plan ÚNICAS por nombre (`plan`), tomadas de todos
    # los planes excepto los IDs excluidos. No importa si un plan ya tiene curso: lo
    # que interesa es el conjunto de nombres de plan que debe existir en cada curso.
    # Representante por nombre: se prefiere el plan sin curso (el "original"); si no
    # hay, se usa el de menor id.
    candidates = WeeklyPlan.where.not(id: exclude_ids).order(:id)
    templates  = candidates
                 .group_by(&:plan)
                 .map { |_name, plans| plans.find { |p| p.course_id.nil? } || plans.min_by(&:id) }
                 .sort_by(&:id)
    courses    = Course.order(:id)

    puts "=" * 72
    puts "Modo:      #{apply ? 'APLICAR (se escribirá en la DB)' : 'DRY-RUN (no se escribe nada)'}"
    puts "Entorno:   #{Rails.env}"
    puts "Excluidos: #{exclude_ids.inspect}"
    puts "=" * 72

    if templates.empty?
      puts "No hay planes plantilla (sin curso) para replicar. Nada que hacer."
      next
    end
    if courses.empty?
      puts "No hay cursos en la base de datos. Nada que hacer."
      next
    end

    puts "\nPlanes plantilla a replicar (#{templates.count}):"
    templates.each { |t| puts "  ##{t.id}  #{t.plan}  ($#{t.price || 0}, #{t.event_type || 'normal'})" }
    puts "\nCursos destino (#{courses.count}):"
    courses.each { |c| puts "  ##{c.id}  #{c.title}" }
    puts

    created = 0
    skipped = 0
    actions = []

    ActiveRecord::Base.transaction do
      courses.each do |course|
        templates.each do |template|
          existing = WeeklyPlan.find_by(course_id: course.id, plan: template.plan)
          if existing
            skipped += 1
            actions << "  SKIP   [#{course.title}] '#{template.plan}' (ya existe, ##{existing.id})"
            next
          end

          attrs = template.attributes.slice(*copyable).merge("course_id" => course.id, "plan" => template.plan)

          if apply
            plan = WeeklyPlan.create!(attrs)
            actions << "  CREATE [#{course.title}] '#{template.plan}' -> ##{plan.id}"
          else
            actions << "  CREATE [#{course.title}] '#{template.plan}' (dry-run)"
          end
          created += 1
        end
      end

      # En dry-run revertimos por si algo se hubiera escrito accidentalmente.
      raise ActiveRecord::Rollback unless apply
    end

    puts actions.join("\n")
    puts "\n" + "=" * 72
    puts "Resumen: #{created} #{apply ? 'creados' : 'a crear'}, #{skipped} omitidos (ya existían)."
    unless apply
      puts "\nDRY-RUN: no se escribió nada. Para aplicar:  APPLY=1 bin/rails plans:replicate_to_courses"
    end
    puts "=" * 72
  end
end
