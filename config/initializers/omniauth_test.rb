# frozen_string_literal: true

# OmniAuth test mode configuration for development
if Rails.env.development?
  # Enable OmniAuth test mode
  OmniAuth.config.test_mode = true
  
  # Mock Google OAuth responses for development
  # Default user (Developer)
  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
    provider: 'google_oauth2',
    uid: 'dev_user_001',
    info: {
      email: 'developer@agrr.dev',
      name: '開発者',
      image: 'https://via.placeholder.com/50x50.png?text=DEV'
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
      image: 'https://via.placeholder.com/50x50.png?text=FARM'
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
      image: 'https://via.placeholder.com/50x50.png?text=RES'
    },
    credentials: {
      token: 'mock_token_researcher_003',
      refresh_token: 'mock_refresh_token_researcher_003',
      expires_at: 1.hour.from_now.to_i
    }
  )
  
  # Failure scenario
  OmniAuth.config.mock_auth[:google_oauth2_fail] = :invalid_credentials
end
