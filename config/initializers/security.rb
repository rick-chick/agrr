# frozen_string_literal: true

# Security configuration for the application

# Force HTTPS in production
if Rails.env.production?
  Rails.application.config.force_ssl = true
end

# Secure headers
Rails.application.config.force_ssl = true if Rails.env.production?

# Configure secure cookies
Rails.application.config.session_store :cookie_store,
  key: '_agrr_session',
  secure: Rails.env.production?,
  httponly: true,
  same_site: :strict

# Content Security Policy
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data, "https://fonts.gstatic.com"
    policy.img_src     :self, :data, "https:", "http:"
    policy.object_src  :none
    policy.script_src  :self, "https://accounts.google.com"
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.connect_src :self, "https://accounts.google.com", "https://tile.openstreetmap.org"
    
    # For OAuth redirects
    policy.form_action :self, "https://accounts.google.com"
  end

  # Generate nonces for inline scripts if needed
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
end

# Rate limiting configuration (would use rack-attack gem in production)
Rails.application.config.middleware.insert_before 0, Rack::Attack if Rails.env.production?

# Configure Rack::Attack for rate limiting
if Rails.env.production?
  Rails.application.configure do
    config.middleware.use Rack::Attack
  end

  # Rate limiting rules
  Rack::Attack.throttle('auth/ip', limit: 5, period: 1.minute) do |req|
    if req.path.start_with?('/auth/')
      req.ip
    end
  end

  Rack::Attack.throttle('api/ip', limit: 100, period: 1.minute) do |req|
    if req.path.start_with?('/api/')
      req.ip
    end
  end
end

