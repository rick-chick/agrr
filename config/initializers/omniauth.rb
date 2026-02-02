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

# Configure mock authentication for development and test environments
if Rails.env.development? || Rails.env.test?
  OmniAuth.config.test_mode = true

  # Mock authentication data for testing
  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
    'provider' => 'google_oauth2',
    'uid' => '123456789',
    'info' => {
      'name' => '開発者',
      'email' => 'developer@agrr.dev',
      'image' => '/assets/dev-avatar.svg',
      'first_name' => '開発',
      'last_name' => '者'
    },
    'credentials' => {
      'token' => 'mock_token',
      'expires_at' => Time.now.to_i + 3600,
      'expires' => true
    },
    'extra' => {
      'raw_info' => {
        'sub' => '123456789',
        'email_verified' => true,
        'locale' => 'ja'
      }
    }
  })

  OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new({
    'provider' => 'google_oauth2',
    'uid' => 'dev_user_001',
    'info' => {
      'name' => '開発者',
      'email' => 'developer@agrr.dev',
      'image' => 'dev-avatar.svg',
      'first_name' => '開発',
      'last_name' => '者'
    },
    'credentials' => {
      'token' => 'mock_token',
      'expires_at' => Time.now.to_i + 3600,
      'expires' => true
    },
    'extra' => {
      'raw_info' => {
        'sub' => 'dev_user_001',
        'email_verified' => true,
        'locale' => 'ja'
      }
    }
  })

  OmniAuth.config.mock_auth[:google_oauth2_farmer] = OmniAuth::AuthHash.new({
    'provider' => 'google_oauth2',
    'uid' => 'farmer_user_001',
    'info' => {
      'name' => '農家ユーザー',
      'email' => 'farmer@agrr.dev',
      'image' => '/assets/farmer-avatar.svg',
      'first_name' => '農家',
      'last_name' => 'ユーザー'
    },
    'credentials' => {
      'token' => 'mock_token',
      'expires_at' => Time.now.to_i + 3600,
      'expires' => true
    },
    'extra' => {
      'raw_info' => {
        'sub' => 'farmer_user_001',
        'email_verified' => true,
        'locale' => 'ja'
      }
    }
  })

  OmniAuth.config.mock_auth[:google_oauth2_researcher] = OmniAuth::AuthHash.new({
    'provider' => 'google_oauth2',
    'uid' => 'researcher_user_001',
    'info' => {
      'name' => '研究者ユーザー',
      'email' => 'researcher@agrr.dev',
      'image' => '/assets/researcher-avatar.svg',
      'first_name' => '研究者',
      'last_name' => 'ユーザー'
    },
    'credentials' => {
      'token' => 'mock_token',
      'expires_at' => Time.now.to_i + 3600,
      'expires' => true
    },
    'extra' => {
      'raw_info' => {
        'sub' => 'researcher_user_001',
        'email_verified' => true,
        'locale' => 'ja'
      }
    }
  })

  Rails.logger.info "🔧 OmniAuth: Mock authentication configured for development/test"
end

# Rails 8 specific configuration
Rails.application.config.after_initialize do
  # Ensure OmniAuth middleware is properly configured
  if ENV['GOOGLE_CLIENT_ID'].present? && ENV['GOOGLE_CLIENT_SECRET'].present?
    Rails.logger.info "✅ OmniAuth: Google OAuth2 configured successfully"
    Rails.logger.info "   Provider: google_oauth2"
    Rails.logger.info "   OAuth URL: /auth/google_oauth2"
    Rails.logger.info "   Callback URL: /auth/google_oauth2/callback"
  elsif Rails.env.development? || Rails.env.test?
    Rails.logger.info "🔧 OmniAuth: Using mock authentication for development/test"
  else
    Rails.logger.warn "⚠️  OmniAuth: No authentication provider configured"
  end
end