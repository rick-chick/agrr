# frozen_string_literal: true

require "test_helper"

class OauthIntegrationTest < ActionDispatch::IntegrationTest
  # リダイレクト先URLを取得するヘルパーメソッド（パス部分のみ）
  def redirect_url
    return nil unless response.location
    URI.parse(response.location).path
  end

  def setup
    OmniAuth.config.test_mode = true
    # Save original mock auth
    @original_mock_auth = OmniAuth.config.mock_auth[:google_oauth2]
  end

  def teardown
    OmniAuth.config.test_mode = false
    # Restore original mock auth
    OmniAuth.config.mock_auth[:google_oauth2] = @original_mock_auth
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

    # Start OAuth flow and complete callback
    assert_difference 'User.count', 1 do
      get '/auth/google_oauth2'
      follow_redirect!
    end

    assert_response :redirect
    # root_urlは絶対URL、redirect_urlは相対パスなので比較方法を変更
    assert_equal '/', redirect_url

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
    
    # 既存のセッションを削除（クリーンな状態でテスト）
    existing_user.sessions.destroy_all

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
      get '/auth/google_oauth2'
      follow_redirect!
    end

    assert_response :redirect
    # root_urlは絶対URL、redirect_urlは相対パスなので比較方法を変更
    assert_equal '/', redirect_url

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

    get '/auth/google_oauth2'
    follow_redirect!
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
        get '/auth/google_oauth2'
        follow_redirect!
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
    # Googleアイコンが含まれるためテキストマッチを緩和
    assert_select 'a[href="/auth/google_oauth2"]', text: /Sign in with Google/
  end

  test "root shows free plan page when not authenticated" do
    # トップページは無料プラン画面（認証不要）
    get '/'
    assert_response :success
    assert_select 'h1', '🌱 作付け計画作成'
  end

  test "authenticated users can also access free plan page" do
    # Create user and session
    user = User.create!(
      email: 'dashboard@example.com',
      name: 'Dashboard User',
      google_id: 'dashboard_google_user',
      avatar_url: 'https://example.com/dashboard.jpg'
    )
    session_id = create_session_for(user)
    auth_headers = session_cookie_header(session_id)

    get '/', headers: auth_headers
    assert_response :success
    assert_select 'h1', '🌱 作付け計画作成'
  end
end

