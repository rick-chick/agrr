require "test_helper"

class AuthTestControllerTest < ActionController::TestCase
  tests AuthTestController

  def test_mock_login_redirects_to_return_to_when_param_return_to_present
    get :mock_login_as, params: { user: 'developer', return_to: 'http://localhost:4200/dashboard' }

    assert_redirected_to 'http://localhost:4200/dashboard'
  end

  def test_mock_login_redirects_to_return_to_when_session_return_to_present
    @request.session[:return_to] = 'http://localhost:4200/dashboard'

    get :mock_login_as, params: { user: 'developer' }

    assert_redirected_to 'http://localhost:4200/dashboard'
  end

  def test_mock_login_redirects_to_root_when_no_return_to
    get :mock_login_as, params: { user: 'developer' }

    assert_redirected_to root_path(locale: I18n.default_locale)
  end

  def test_mock_login_redirects_to_process_saved_plan_when_session_data_present
    @request.session[:public_plan_save_data] = {
      plan_id: 1,
      farm_id: 1,
      crop_ids: [],
      field_data: []
    }

    get :mock_login_as, params: { user: 'developer' }
    assert_redirected_to process_saved_plan_public_plans_path
  end

  def test_mock_login_as_without_mock_data_returns_translated_alert
    OmniAuth.config.mock_auth[:developer] = nil

    get :mock_login_as, params: { user: 'developer' }

    assert_redirected_to root_path(locale: I18n.default_locale)
    assert_equal I18n.t('auth_test.mock_data_missing'), flash[:alert]
  end
end
