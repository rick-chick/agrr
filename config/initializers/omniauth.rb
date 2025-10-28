# frozen_string_literal: true

# OmniAuth configuration for Google OAuth2 (enabled in all environments)
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
# Allow GET requests in test/dev
if Rails.env.test? || Rails.env.development?
  OmniAuth.config.allowed_request_methods = [:get, :post]
end
OmniAuth.config.silence_get_warning = true

# Set secure callback URL
OmniAuth.config.full_host = lambda do |env|
  scheme = env['rack.url_scheme']
  host = env['HTTP_HOST']
  "#{scheme}://#{host}"
end

