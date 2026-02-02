Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    allowed_origins = [
      'http://localhost:4200',
      'http://localhost:4201',
      'http://127.0.0.1:4200',
      'http://127.0.0.1:4201'
    ]
    env_origins = ENV.fetch('CORS_ALLOWED_ORIGINS', '')
                      .split(',')
                      .map(&:strip)
                      .reject(&:empty?)
    origins(*(allowed_origins + env_origins))

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end