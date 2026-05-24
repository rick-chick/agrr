require "test_helper"

class AuthControllerTest < ActionController::TestCase
  tests AuthController

  def setup
    # Mock OmniAuth callback data
    @request.env["omniauth.auth"] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "test_uid_001",
      info: {
        email: "testuser@example.com",
        name: "テストユーザー",
        image: "dev-avatar.svg"
      },
      credentials: {
        token: "mock_token",
        refresh_token: "mock_refresh",
        expires_at: 1.hour.from_now.to_i
      }
    )
  end

  def test_callback_redirects_to_process_saved_plan_when_session_data_present
    @request.session[:public_plan_save_data] = {
      plan_id: 1,
      farm_id: 1,
      crop_ids: [],
      field_data: []
    }

    get :google_oauth2_callback
    assert_redirected_to "http://localhost:4200/public-plans/results?planId=1", allow_other_host: true
  end

  def test_callback_redirects_to_return_to_when_set
    @request.session[:return_to] = "http://localhost:4200/"

    get :google_oauth2_callback
    assert_redirected_to "http://localhost:4200/?_agrr_oauth=1", allow_other_host: true
    assert_nil session[:return_to]
  end

  def test_callback_appends_conversion_query_when_return_to_has_existing_params
    @request.session[:return_to] = "http://localhost:4200/dashboard?plan=1"

    get :google_oauth2_callback
    redirected = URI.parse(response.redirect_url)
    assert_equal "4200", redirected.port.to_s
    assert_equal "/dashboard", redirected.path
    q = Rack::Utils.parse_query(redirected.query)
    assert_equal "1", q["plan"]
    assert_equal "1", q["_agrr_oauth"]
    assert_nil session[:return_to]
  end

  def test_login_stores_allowed_return_to
    get :login, params: { return_to: "http://localhost:4200/dashboard" }
    assert_equal "http://localhost:4200/dashboard", session[:return_to]
  end

  def test_login_ignores_disallowed_return_to
    get :login, params: { return_to: "https://evil.example.com/" }
    assert_nil session[:return_to]
  end
end
