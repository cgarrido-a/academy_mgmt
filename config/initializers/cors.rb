# config/initializers/cors.rb

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Especifica los orígenes permitidos de tu frontend
    # Para desarrollo local, usa localhost con los puertos comunes
    # Para producción, agrega tu dominio a la lista o usa la variable FRONTEND_URL

    allowed_origins = [
      'http://localhost:3000',   # Create React App, Next.js
      'http://localhost:5173',   # Vite
      'http://localhost:4200',   # Angular
      'http://localhost:8080',   # Vue CLI
      'https://www.gustarte.cl', # Producción
      'https://gustarte.cl',     # Producción (sin www)
      ENV['FRONTEND_URL']        # Variable de entorno para producción
    ].compact  # Elimina valores nil

    origins allowed_origins

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
