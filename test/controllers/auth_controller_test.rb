require "test_helper"

class AuthControllerTest < ActionController::TestCase
  tests AuthController

  def setup
    # Mock OmniAuth callback data
    @request.env['omniauth.auth'] = OmniAuth::AuthHash.new(
      provider: 'google_oauth2',
      uid: 'test_uid_001',
      info: {
        email: 'testuser@example.com',
        name: 'テストユーザー',
        image: 'dev-avatar.svg'
      },
      credentials: {
        token: 'mock_token',
        refresh_token: 'mock_refresh',
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
    assert_redirected_to process_saved_plan_public_plans_path
  end
end
