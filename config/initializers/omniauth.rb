# frozen_string_literal: true

# OmniAuth configuration for Google OAuth2 (Rails 8 compatible)
Rails.application.config.middleware.use OmniAuth::Builder do
  # Check if credentials are available
  if ENV['GOOGLE_CLIENT_ID'].present? && ENV['GOOGLE_CLIENT_SECRET'].present?
    provider :google_oauth2, 
      ENV['GOOGLE_CLIENT_ID'], 
      ENV['GOOGLE_CLIENT_SECRET'],
      {
        scope: 'email,profile',
        prompt: 'select_account',
        image_aspect_ratio: 'square',
        image_size: 50,
        access_type: 'offline',
        provider_ignores_state: false,
        skip_jwt: true
      }
  else
    Rails.logger.error "🚨 OmniAuth: Google OAuth credentials not configured!"
    Rails.logger.error "   GOOGLE_CLIENT_ID: #{ENV['GOOGLE_CLIENT_ID'].present? ? 'SET' : 'NOT SET'}"
    Rails.logger.error "   GOOGLE_CLIENT_SECRET: #{ENV['GOOGLE_CLIENT_SECRET'].present? ? 'SET' : 'NOT SET'}"
  end
end

# Configure OmniAuth for security
# Rails 8 requires CSRF protection for OmniAuth
OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.silence_get_warning = true

# Allow GET requests in development for easier testing
if Rails.env.development?
  OmniAuth.config.allowed_request_methods = [:get, :post]
end

# Set secure callback URL
OmniAuth.config.full_host = lambda do |env|
  scheme = env['rack.url_scheme']
  host = env['HTTP_HOST']
  "#{scheme}://#{host}"
end

# Rails 8 specific configuration
Rails.application.config.after_initialize do
  # Ensure OmniAuth middleware is properly configured
  if ENV['GOOGLE_CLIENT_ID'].present? && ENV['GOOGLE_CLIENT_SECRET'].present?
    Rails.logger.info "✅ OmniAuth: Google OAuth2 configured successfully"
    Rails.logger.info "   Provider: google_oauth2"
    Rails.logger.info "   OAuth URL: /auth/google_oauth2"
    Rails.logger.info "   Callback URL: /auth/google_oauth2/callback"
  end
end