module Api
  module V1
    class SectionsController < BaseController
      # GET /api/v1/sections/:id/calendar
      # Optional params: from (YYYY-MM-DD), to (YYYY-MM-DD)
      # Defaults: from=today, to=today+3months
      # Returns all dates for this section's weekday within the range, with availability
      def calendar
        section = Section.find(params[:id])

        # Default: próximos 3 meses desde hoy
        from_date = params[:from].present? ? Date.parse(params[:from]) : Date.today
        to_date = params[:to].present? ? Date.parse(params[:to]) : (Date.today + 3.months)

        # Generate all dates that match this section's weekday
        dates_with_availability = generate_dates_for_weekday(
          section.weekday,
          from_date,
          to_date
        ).map do |date|
          {
            date: date,
            available_places: section.available_places_for_date(date),
            total_places: section.places,
            enrolled_count: section.places - section.available_places_for_date(date)
          }
        end

        render json: {
          success: true,
          data: {
            section_id: section.id,
            course: section.course.title,
            weekday: section.weekday,
            schedule: section.schedule,
            teacher_name: section.teacher.user.name,
            total_places: section.places,
            dates: dates_with_availability
          }
        }
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: 'Section not found'
        }, status: :not_found
      rescue ArgumentError => e
        render json: {
          success: false,
          error: "Invalid date format. Use YYYY-MM-DD. Error: #{e.message}"
        }, status: :bad_request
      end

      # GET /api/v1/sections/:id/preview_class_dates
      # Params: start_date (YYYY-MM-DD), weekly_plan_id (integer), months (integer, optional)
      # Returns the dates that would be assigned for an enrollment
      def preview_class_dates
        puts "Params received: #{params.inspect}"
        section = Section.find(params[:id])
        start_date = Date.parse(params[:start_date])
        weekly_plan = WeeklyPlan.find(params[:weekly_plan_id])

        # If months parameter is provided, calculate number_of_classes based on period.
        # OJO: este endpoint genera las fechas de UNA sola sección, y el formulario
        # lo llama una vez por sección seleccionada. Cada sección aporta 1 clase por
        # semana, así que por sección corresponden (months × 4) fechas. El factor
        # weekly_classes NO va aquí: ya viene dado por la cantidad de secciones que
        # el plan obliga a elegir (weekly_classes secciones). Multiplicarlo también
        # aquí duplicaba las clases (p. ej. plan de 2 clases/sem mostraba 16 en vez de 8).
        if params[:months].present?
          months = params[:months].to_i
          weeks_in_period = months * 4
          number_of_classes = weeks_in_period
        else
          # Fallback to plan's per-section classes when no period is given.
          number_of_classes = weekly_plan.number_of_classes
        end

        if number_of_classes.nil?
          return render json: {
            success: false,
            error: 'El plan semanal no tiene número de clases configurado'
          }, status: :bad_request
        end

        if number_of_classes <= 0
          return render json: {
            success: false,
            error: 'El plan semanal debe tener al menos 1 clase'
          }, status: :bad_request
        end

        # Generate class dates with availability check (include skipped dates info)
        result = generate_class_dates_with_details(section, start_date, number_of_classes)

        # Format assigned dates
        assigned_dates_data = result[:assigned_dates].map do |date|
          {
            date: date,
            formatted_date: date.strftime('%d/%m/%Y'),
            weekday: I18n.l(date, format: '%A'),
            available_places: section.available_places_for_date(date),
            total_places: section.places,
            status: 'assigned'
          }
        end

        # Format skipped dates
        skipped_dates_data = result[:skipped_dates].map do |date|
          {
            date: date,
            formatted_date: date.strftime('%d/%m/%Y'),
            weekday: I18n.l(date, format: '%A'),
            available_places: section.available_places_for_date(date),
            total_places: section.places,
            status: 'skipped',
            reason: 'Sin cupos disponibles'
          }
        end

        render json: {
          success: true,
          data: {
            section_id: section.id,
            course: section.course.title,
            weekday: section.weekday,
            schedule: section.schedule,
            teacher_name: section.teacher.user.name,
            weekly_plan: {
              id: weekly_plan.id,
              plan: weekly_plan.plan,
              description: weekly_plan.description,
              number_of_classes: number_of_classes,
              weekly_classes: weekly_plan.weekly_classes,
              price: weekly_plan.price
            },
            start_date: start_date,
            assigned_dates: assigned_dates_data,
            skipped_dates: skipped_dates_data,
            total_assigned: assigned_dates_data.length,
            total_skipped: skipped_dates_data.length
          }
        }
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: 'Section not found'
        }, status: :not_found
      rescue ArgumentError => e
        render json: {
          success: false,
          error: "Invalid parameters. #{e.message}"
        }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error "Error en preview_class_dates: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: {
          success: false,
          error: e.message
        }, status: :unprocessable_entity
      end

      private

      def generate_class_dates_with_details(section, start_date, number_of_classes)
        # Map Spanish weekday names to Ruby's wday (0 = Sunday, 1 = Monday, etc.)
        weekday_map = {
          'Domingo' => 0,
          'Lunes' => 1,
          'Martes' => 2,
          'Miércoles' => 3,
          'Jueves' => 4,
          'Viernes' => 5,
          'Sábado' => 6
        }

        target_wday = weekday_map[section.weekday]
        assigned_dates = []
        skipped_dates = []
        current_date = start_date

        # Ensure start_date matches the section's weekday
        unless current_date.wday == target_wday
          raise ArgumentError, "La fecha de inicio #{start_date.strftime('%d/%m/%Y')} no es un #{section.weekday}"
        end

        # Generate the specified number of class dates with available spots
        max_attempts = number_of_classes * 10  # Evitar bucle infinito
        attempts = 0

        while assigned_dates.length < number_of_classes && attempts < max_attempts
          # Check if this date has available places
          if section.has_available_places_for_date?(current_date)
            assigned_dates << current_date
          else
            # Track skipped dates (dates without available spots)
            skipped_dates << current_date
          end

          current_date += 7.days  # Next week, same day
          attempts += 1
        end

        if assigned_dates.length < number_of_classes
          raise StandardError, "No se pudieron encontrar #{number_of_classes} fechas con cupos disponibles. Solo se encontraron #{assigned_dates.length} fechas."
        end

        {
          assigned_dates: assigned_dates,
          skipped_dates: skipped_dates
        }
      end

      def generate_class_dates(section, start_date, number_of_classes)
        # Map Spanish weekday names to Ruby's wday (0 = Sunday, 1 = Monday, etc.)
        weekday_map = {
          'Domingo' => 0,
          'Lunes' => 1,
          'Martes' => 2,
          'Miércoles' => 3,
          'Jueves' => 4,
          'Viernes' => 5,
          'Sábado' => 6
        }

        target_wday = weekday_map[section.weekday]
        dates = []
        current_date = start_date

        # Ensure start_date matches the section's weekday
        unless current_date.wday == target_wday
          raise ArgumentError, "La fecha de inicio #{start_date.strftime('%d/%m/%Y')} no es un #{section.weekday}"
        end

        # Generate the specified number of class dates with available spots
        max_attempts = number_of_classes * 10  # Evitar bucle infinito
        attempts = 0

        while dates.length < number_of_classes && attempts < max_attempts
          # Check if this date has available places
          if section.has_available_places_for_date?(current_date)
            dates << current_date
          end
          # If no spots available, skip to next week

          current_date += 7.days  # Next week, same day
          attempts += 1
        end

        if dates.length < number_of_classes
          raise StandardError, "No se pudieron encontrar #{number_of_classes} fechas con cupos disponibles. Solo se encontraron #{dates.length} fechas."
        end

        dates
      end

      def generate_dates_for_weekday(weekday_name, from_date, to_date)
        # Map Spanish weekday names to Ruby's wday (0 = Sunday, 1 = Monday, etc.)
        weekday_map = {
          'Domingo' => 0,
          'Lunes' => 1,
          'Martes' => 2,
          'Miércoles' => 3,
          'Jueves' => 4,
          'Viernes' => 5,
          'Sábado' => 6
        }

        target_wday = weekday_map[weekday_name]

        unless target_wday
          raise ArgumentError, "Invalid weekday: #{weekday_name}"
        end

        dates = []
        current_date = from_date

        # Find the first occurrence of the target weekday
        while current_date.wday != target_wday && current_date <= to_date
          current_date += 1.day
        end

        # Collect all dates that match the weekday
        while current_date <= to_date
          dates << current_date
          current_date += 7.days
        end

        dates
      end
    end
  end
end
