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
  same_site: :lax  # :strict だとWebSocket接続でCookieが送信されない

# Content Security Policy
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data, "https://fonts.gstatic.com"
    policy.img_src     :self, :data, "https:", "http:"
    policy.object_src  :none
    policy.script_src  :self, "https://accounts.google.com", "https://pagead2.googlesyndication.com", "https://adservice.google.com", "https://www.googletagmanager.com", "https://www.google-analytics.com"
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com"
    # WebSocket接続のため wss: を追加
    policy.connect_src :self, "wss:", "https://accounts.google.com", "https://tile.openstreetmap.org", "https://www.google-analytics.com", "https://analytics.google.com"
    
    # For OAuth redirects
    policy.form_action :self, "https://accounts.google.com"
    
    # Google AdSense (広告をiframeで表示)
    policy.frame_src   :self, "https://googleads.g.doubleclick.net", "https://tpc.googlesyndication.com"
  end

  # Generate nonces for inline scripts if needed
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  
  # Only apply nonce to scripts, not styles
  # This allows inline styles (used by JavaScript) while protecting against script injection
  config.content_security_policy_nonce_directives = %w[script-src]
end

# Rate limiting configuration (rack-attack gem in production)
if defined?(Rack::Attack) && Rails.env.production?
  Rails.application.config.middleware.insert_before 0, Rack::Attack

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

