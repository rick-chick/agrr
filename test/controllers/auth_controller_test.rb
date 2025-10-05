# frozen_string_literal: true

require "test_helper"

class AuthControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: 'test@example.com',
      name: 'Test User',
      google_id: 'google123456789',
      avatar_url: 'https://example.com/avatar.jpg'
    )
  end

  test "should get login page" do
    get '/auth/login'
    assert_response :success
    assert_select 'a[href="/auth/google_oauth2"]', 'Sign in with Google'
  end

  test "should redirect to Google OAuth" do
    get '/auth/google_oauth2'
    assert_response :redirect
    assert_match /accounts\.google\.com/, redirect_url
  end

  test "should handle successful OAuth callback" do
    # Mock OmniAuth response
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: 'google_oauth2',
      uid: 'google123456789',
      info: {
        email: 'test@example.com',
        name: 'Test User',
        image: 'https://example.com/avatar.jpg'
      }
    )

    # Mock session
    session[:user_id] = @user.id

    get '/auth/google_oauth2/callback'
    assert_response :redirect
    assert_equal root_url, redirect_url
  end

  test "should handle failed OAuth callback" do
    # Mock failed OmniAuth response
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials

    get '/auth/google_oauth2/callback'
    assert_response :redirect
    assert_equal '/auth/failure', redirect_url
  end

  test "should handle OAuth failure" do
    get '/auth/failure'
    assert_response :redirect
    assert_equal '/auth/login', redirect_url
    assert_equal 'Authentication failed. Please try again.', flash[:alert]
  end

  test "should logout user" do
    # Set up authenticated session
    session = Session.create_for_user(@user)
    cookies[:session_id] = session.session_id

    delete '/auth/logout'
    assert_response :redirect
    assert_equal '/auth/login', redirect_url
    assert_equal 'Logged out successfully.', flash[:notice]
  end

  test "should create new user from OAuth callback" do
    # Mock new user OAuth response
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: 'google_oauth2',
      uid: 'new_google_user',
      info: {
        email: 'newuser@example.com',
        name: 'New User',
        image: 'https://example.com/new_avatar.jpg'
      }
    )

    assert_difference 'User.count', 1 do
      assert_difference 'Session.count', 1 do
        get '/auth/google_oauth2/callback'
      end
    end

    assert_response :redirect
    assert_equal root_url, redirect_url

    new_user = User.find_by(google_id: 'new_google_user')
    assert_not_nil new_user
    assert_equal 'newuser@example.com', new_user.email
    assert_equal 'New User', new_user.name
  end

  test "should update existing user from OAuth callback" do
    # Mock updated user info
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: 'google_oauth2',
      uid: 'google123456789',
      info: {
        email: 'test@example.com',
        name: 'Updated Name',
        image: 'https://example.com/updated_avatar.jpg'
      }
    )

    assert_no_difference 'User.count' do
      get '/auth/google_oauth2/callback'
    end

    @user.reload
    assert_equal 'Updated Name', @user.name
    assert_equal 'https://example.com/updated_avatar.jpg', @user.avatar_url
  end

  test "should require authentication for protected routes" do
    get '/api/v1/files'
    assert_response :unauthorized
    assert_equal 'Please log in to access this resource.', JSON.parse(response.body)['error']
  end

  test "should allow access with valid session" do
    session = Session.create_for_user(@user)
    cookies[:session_id] = session.session_id

    get '/api/v1/files'
    assert_response :success
  end

  test "should deny access with expired session" do
    session = Session.create_for_user(@user)
    session.update!(expires_at: 1.day.ago)
    cookies[:session_id] = session.session_id

    get '/api/v1/files'
    assert_response :unauthorized
  end

  test "should deny access with invalid session" do
    cookies[:session_id] = 'invalid_session_id'

    get '/api/v1/files'
    assert_response :unauthorized
  end
end

