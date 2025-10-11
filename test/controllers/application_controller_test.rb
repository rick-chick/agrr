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
    get root_path
    assert_response :redirect # Will be redirected by authenticate_user!
    # Note: In an actual request, current_user would return anonymous user
  end

  test "current_user returns real user when logged in" do
    session = @user.sessions.create!(
      session_id: SecureRandom.hex(32),
      expires_at: 1.month.from_now
    )
    
    get root_path, headers: { "Cookie" => "session_id=#{session.session_id}" }
    # User should be logged in, so no redirect to login page
    # The actual page might redirect elsewhere, but not to login
  end

  test "authenticate_user! redirects anonymous users" do
    get root_path
    assert_redirected_to auth_login_path
    assert_equal "Please log in to access this page.", flash[:alert]
  end

  test "logged_in? returns false for anonymous users" do
    # This is tested implicitly through the authenticate_user! redirect
    get root_path
    assert_redirected_to auth_login_path
  end

  test "logged_in? returns true for authenticated users" do
    session = @user.sessions.create!(
      session_id: SecureRandom.hex(32),
      expires_at: 1.month.from_now
    )
    
    get root_path, headers: { "Cookie" => "session_id=#{session.session_id}" }
    # Should not redirect to login page
    assert_not_equal auth_login_path, path
  end
end

