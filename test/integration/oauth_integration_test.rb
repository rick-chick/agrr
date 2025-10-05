# frozen_string_literal: true

require "test_helper"

class OauthIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  def teardown
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  test "complete OAuth flow for new user" do
    # Mock successful OAuth response
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: 'google_oauth2',
      uid: 'new_google_user_123',
      info: {
        email: 'newuser@example.com',
        name: 'New User',
        image: 'https://example.com/new_avatar.jpg'
      }
    )

    # Start OAuth flow
    get '/auth/google_oauth2'
    assert_response :redirect
    assert_match /accounts\.google\.com/, redirect_url

    # Complete OAuth callback
    assert_difference 'User.count', 1 do
      assert_difference 'Session.count', 1 do
        get '/auth/google_oauth2/callback'
      end
    end

    assert_response :redirect
    assert_equal root_url, redirect_url

    # Verify user was created
    user = User.find_by(google_id: 'new_google_user_123')
    assert_not_nil user
    assert_equal 'newuser@example.com', user.email
    assert_equal 'New User', user.name
    assert_equal 'https://example.com/new_avatar.jpg', user.avatar_url

    # Verify session was created
    session = Session.find_by(user: user)
    assert_not_nil session
    assert session.expires_at > Time.current

    # Verify cookie was set
    assert cookies[:session_id].present?
    assert_equal session.session_id, cookies[:session_id]
  end

  test "complete OAuth flow for existing user" do
    # Create existing user
    existing_user = User.create!(
      email: 'existing@example.com',
      name: 'Existing User',
      google_id: 'existing_google_user',
      avatar_url: 'https://example.com/existing.jpg'
    )

    # Mock OAuth response with updated info
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: 'google_oauth2',
      uid: 'existing_google_user',
      info: {
        email: 'existing@example.com',
        name: 'Updated Name',
        image: 'https://example.com/updated_avatar.jpg'
      }
    )

    # Complete OAuth callback
    assert_no_difference 'User.count' do
      assert_difference 'Session.count', 1 do
        get '/auth/google_oauth2/callback'
      end
    end

    assert_response :redirect
    assert_equal root_url, redirect_url

    # Verify user was updated
    existing_user.reload
    assert_equal 'Updated Name', existing_user.name
    assert_equal 'https://example.com/updated_avatar.jpg', existing_user.avatar_url

    # Verify session was created
    session = Session.find_by(user: existing_user)
    assert_not_nil session
  end

  test "OAuth failure handling" do
    # Mock failed OAuth response
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials

    get '/auth/google_oauth2/callback'
    assert_response :redirect
    assert_equal '/auth/failure', redirect_url

    get '/auth/failure'
    assert_response :redirect
    assert_equal '/auth/login', redirect_url
    assert_equal 'Authentication failed. Please try again.', flash[:alert]
  end

  test "OAuth callback with missing data" do
    # Mock OAuth response with missing required fields
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: 'google_oauth2',
      uid: nil,  # Missing UID
      info: {}
    )

    assert_no_difference 'User.count' do
      assert_no_difference 'Session.count' do
        get '/auth/google_oauth2/callback'
      end
    end

    assert_response :redirect
    assert_equal '/auth/failure', redirect_url
  end

  test "logout flow" do
    # Create user and session
    user = User.create!(
      email: 'logout@example.com',
      name: 'Logout User',
      google_id: 'logout_google_user',
      avatar_url: 'https://example.com/logout.jpg'
    )
    session = Session.create_for_user(user)
    cookies[:session_id] = session.session_id

    # Verify user is authenticated
    get '/api/v1/files'
    assert_response :success

    # Logout
    delete '/auth/logout'
    assert_response :redirect
    assert_equal '/auth/login', redirect_url
    assert_equal 'Logged out successfully.', flash[:notice]

    # Verify session was destroyed
    assert_not Session.exists?(session.id)

    # Verify user is no longer authenticated
    get '/api/v1/files'
    assert_response :unauthorized
  end

  test "session expiration handling" do
    # Create user and expired session
    user = User.create!(
      email: 'expired@example.com',
      name: 'Expired User',
      google_id: 'expired_google_user',
      avatar_url: 'https://example.com/expired.jpg'
    )
    session = Session.create!(
      session_id: Session.generate_session_id,
      user: user,
      expires_at: 1.day.ago
    )
    cookies[:session_id] = session.session_id

    # Verify expired session is rejected
    get '/api/v1/files'
    assert_response :unauthorized
  end

  test "invalid session ID handling" do
    # Set invalid session ID
    cookies[:session_id] = 'invalid_session_id'

    # Verify invalid session is rejected
    get '/api/v1/files'
    assert_response :unauthorized
  end

  test "protected API endpoints require authentication" do
    # Test various API endpoints
    api_endpoints = [
      '/api/v1/files',
      '/api/v1/files/1',
      '/api/v1/health'
    ]

    api_endpoints.each do |endpoint|
      get endpoint
      if endpoint == '/api/v1/health'
        # Health endpoint should be public
        assert_response :success
      else
        # Other endpoints should require authentication
        assert_response :unauthorized
        assert_equal 'Please log in to access this resource.', JSON.parse(response.body)['error']
      end
    end
  end

  test "login page accessibility" do
    get '/auth/login'
    assert_response :success
    assert_select 'a[href="/auth/google_oauth2"]', 'Sign in with Google'
  end

  test "root redirects to login when not authenticated" do
    get '/'
    assert_response :redirect
    assert_equal '/auth/login', redirect_url
  end

  test "root shows dashboard when authenticated" do
    # Create user and session
    user = User.create!(
      email: 'dashboard@example.com',
      name: 'Dashboard User',
      google_id: 'dashboard_google_user',
      avatar_url: 'https://example.com/dashboard.jpg'
    )
    session = Session.create_for_user(user)
    cookies[:session_id] = session.session_id

    get '/'
    assert_response :success
    assert_select 'h1', 'Welcome to AGRR!'
  end
end

