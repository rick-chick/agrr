# frozen_string_literal: true

# OmniAuth mock profiles for development and test
if Rails.env.development? || Rails.env.test?
  
  # Mock Google OAuth responses for mock-login endpoints
  # Default user (Developer)
  OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
    provider: 'developer',
    uid: 'dev_user_001',
    info: {
      email: 'developer@agrr.dev',
      name: '開発者',
      image: 'dev-avatar.svg'
    },
    credentials: {
      token: 'mock_token_dev_001',
      refresh_token: 'mock_refresh_token_dev_001',
      expires_at: 1.hour.from_now.to_i
    }
  )
  
  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
    provider: 'google_oauth2',
    uid: 'dev_user_001',
    info: {
      email: 'developer@agrr.dev',
      name: '開発者',
      image: 'dev-avatar.svg'
    },
    credentials: {
      token: 'mock_token_dev_001',
      refresh_token: 'mock_refresh_token_dev_001',
      expires_at: 1.hour.from_now.to_i
    }
  )
  
  # Second user (Farmer)
  OmniAuth.config.mock_auth[:google_oauth2_farmer] = OmniAuth::AuthHash.new(
    provider: 'google_oauth2',
    uid: 'farmer_user_002',
    info: {
      email: 'farmer@agrr.dev',
      name: '農家太郎',
      image: 'farm-avatar.svg'
    },
    credentials: {
      token: 'mock_token_farmer_002',
      refresh_token: 'mock_refresh_token_farmer_002',
      expires_at: 1.hour.from_now.to_i
    }
  )
  
  # Third user (Researcher)
  OmniAuth.config.mock_auth[:google_oauth2_researcher] = OmniAuth::AuthHash.new(
    provider: 'google_oauth2',
    uid: 'researcher_user_003',
    info: {
      email: 'researcher@agrr.dev',
      name: '研究員花子',
      image: 'res-avatar.svg'
    },
    credentials: {
      token: 'mock_token_researcher_003',
      refresh_token: 'mock_refresh_token_researcher_003',
      expires_at: 1.hour.from_now.to_i
    }
  )
  
  # Failure scenario (used in tests only)
  OmniAuth.config.mock_auth[:google_oauth2_fail] = :invalid_credentials
end

# Enable OmniAuth test mode ONLY in test so real Google OAuth works in development
if Rails.env.test?
  OmniAuth.config.test_mode = true
end
