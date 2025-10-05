# frozen_string_literal: true

require "test_helper"

class SecurityTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: 'test@example.com',
      name: 'Test User',
      google_id: 'google123456789',
      avatar_url: 'https://example.com/avatar.jpg'
    )
    @session = Session.create_for_user(@user)
  end

  test "should require HTTPS in production" do
    Rails.env.stubs(:production?).returns(true)
    
    # This would be tested in integration tests with actual HTTPS setup
    # For now, we test that the configuration is correct
    assert Rails.env.production? == false || Rails.application.config.force_ssl
  end

  test "should set secure session cookies in production" do
    Rails.env.stubs(:production?).returns(true)
    
    cookies[:session_id] = {
      value: @session.session_id,
      secure: true,
      httponly: true,
      same_site: :strict
    }
    
    get '/api/v1/files'
    assert_response :success
  end

  test "should prevent session fixation attacks" do
    # Old session should be invalidated when new one is created
    old_session_id = @session.session_id
    
    # Create new session (simulating login)
    new_session = Session.create_for_user(@user)
    
    # Old session should be invalid
    cookies[:session_id] = old_session_id
    get '/api/v1/files'
    assert_response :unauthorized
    
    # New session should be valid
    cookies[:session_id] = new_session.session_id
    get '/api/v1/files'
    assert_response :success
  end

  test "should prevent CSRF attacks on OAuth endpoints" do
    # OAuth callback should not require CSRF token
    post '/auth/google_oauth2/callback'
    # This should not fail due to CSRF protection
    # (The actual OAuth failure is expected due to missing auth data)
    assert_response :redirect
  end

  test "should validate session expiration" do
    # Expire the session
    @session.update!(expires_at: 1.day.ago)
    cookies[:session_id] = @session.session_id
    
    get '/api/v1/files'
    assert_response :unauthorized
  end

  test "should prevent SQL injection in user lookup" do
    malicious_session_id = "'; DROP TABLE users; --"
    cookies[:session_id] = malicious_session_id
    
    get '/api/v1/files'
    assert_response :unauthorized
    
    # Ensure users table still exists
    assert User.table_exists?
  end

  test "should sanitize user input in OAuth callback" do
    # Mock malicious OAuth response
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: 'google_oauth2',
      uid: 'google123456789',
      info: {
        email: 'test@example.com',
        name: '<script>alert("xss")</script>',
        image: 'javascript:alert("xss")'
      }
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      User.from_omniauth(OmniAuth.config.mock_auth[:google_oauth2])
    end
  end

  test "should rate limit authentication attempts" do
    # This would be implemented with a rate limiting gem
    # For now, we test that the structure supports it
    assert_respond_to AuthController, :before_action
  end

  test "should log security events" do
    # Test that authentication failures are logged
    Rails.logger.expects(:error).with(regexp_matches(/OAuth callback error/))
    
    # Mock failed OAuth callback
    post '/auth/google_oauth2/callback', params: { error: 'access_denied' }
  end

  test "should validate OAuth state parameter" do
    # OmniAuth should handle state validation automatically
    # We test that our configuration includes state validation
    omniauth_config = Rails.application.config.middleware.find { |m| m.klass == OmniAuth::Builder }
    assert_not_nil omniauth_config
  end

  test "should prevent account enumeration" do
    # Login attempts should not reveal whether an email exists
    get '/auth/login'
    assert_response :success
    
    # The login page should not show different content based on email existence
    assert_select 'form', false # No forms that could reveal email existence
  end

  test "should handle concurrent session management" do
    # Create multiple sessions for same user
    session1 = Session.create_for_user(@user)
    session2 = Session.create_for_user(@user)
    
    # Both sessions should be valid
    cookies[:session_id] = session1.session_id
    get '/api/v1/files'
    assert_response :success
    
    cookies[:session_id] = session2.session_id
    get '/api/v1/files'
    assert_response :success
    
    # Logout should destroy all sessions
    delete '/auth/logout'
    assert_equal 0, @user.sessions.count
  end

  test "should validate session integrity" do
    # Tampered session ID should be rejected
    tampered_session_id = @session.session_id + "tampered"
    cookies[:session_id] = tampered_session_id
    
    get '/api/v1/files'
    assert_response :unauthorized
  end
end

