# frozen_string_literal: true

require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "test@example.com",
      name: "Test User",
      google_id: "test_google_id"
    )
  end

  test "current_user returns anonymous user when not logged in" do
    # トップページは無料プラン（認証不要）のため、farms_pathでテスト
    get farms_path
    assert_response :redirect # Will be redirected by authenticate_user!
    # Note: In an actual request, current_user would return anonymous user
  end

  test "current_user returns real user when logged in" do
    session_id = create_session_for(@user)
    auth_headers = session_cookie_header(session_id)
    
    get farms_path, headers: auth_headers
    # User should be logged in, so no redirect to login page
    assert_response :success
  end

  test "authenticate_user! redirects anonymous users" do
    # トップページは無料プラン（認証不要）のため、farms_pathでテスト
    get farms_path
    assert_redirected_to auth_login_path
    assert_equal "Please log in to access this page.", flash[:alert]
  end

  test "logged_in? returns false for anonymous users" do
    # This is tested implicitly through the authenticate_user! redirect
    get farms_path
    assert_redirected_to auth_login_path
  end

  test "logged_in? returns true for authenticated users" do
    session_id = create_session_for(@user)
    auth_headers = session_cookie_header(session_id)
    
    get farms_path, headers: auth_headers
    # Should not redirect to login page
    assert_response :success
  end
end

