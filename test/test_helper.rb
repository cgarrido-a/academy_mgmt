ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Fixtures desactivados a propósito.
    #
    # Los .yml de test/fixtures son los del scaffold original y quedaron desfasados del
    # schema (enrollments.payment_plan, sections.start_date, users.password, la tabla
    # tuition_fees), así que cargarlos hacía fallar TODOS los tests con
    # "table X has no columns named Y" antes de llegar a correr. Ningún test los usa:
    # todos crean sus propios datos (ver enrollment_creator_test / session_suspender_test).
    # Si algún día se quieren usar, hay que actualizar los .yml al schema actual primero.
    # fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
