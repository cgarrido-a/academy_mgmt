# config/initializers/cors.rb

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Cambia esto por el origen de tu frontend en producción
    origins '*' # En desarrollo permite cualquier origen. En producción, especifica: 'http://localhost:3001', 'https://tu-frontend.com'

    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false
  end
end
