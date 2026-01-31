require "test_helper"

class AuthTestControllerTest < ActionController::TestCase
  tests AuthTestController

  setup do
    # ログイン成功を期待するテスト用に OmniAuth :developer モックを設定（Angular 等へのリダイレクトを検証するため）
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      'provider' => 'developer',
      'uid' => 'dev_user_001',
      'info' => {
        'email' => 'developer@agrr.dev',
        'name' => '開発者',
        'image' => 'dev-avatar.svg'
      }
    )
  end

  def with_env(hash)
    old = {}
    hash.each_key { |k| old[k] = ENV[k] }
    hash.each { |k, v| ENV[k] = v.to_s }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end

  def test_mock_login_redirects_to_return_to_when_param_return_to_present
    with_env('FRONTEND_URL' => 'http://localhost:4200') do
      get :mock_login_as, params: { user: 'developer', return_to: 'http://localhost:4200/dashboard' }

      assert_redirected_to 'http://localhost:4200/dashboard', allow_other_host: true
    end
  end

  def test_mock_login_redirects_to_return_to_when_session_return_to_present
    @request.session[:return_to] = 'http://localhost:4200/dashboard'

    with_env('FRONTEND_URL' => 'http://localhost:4200') do
      get :mock_login_as, params: { user: 'developer' }

      assert_response :redirect
      assert_match %r{localhost:4200/dashboard}, response.redirect_url,
        "Expected redirect to frontend (got #{response.redirect_url})"
    end
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
    assert_response :redirect
    assert_match %r{public_plans/process_saved_plan}, response.redirect_url,
      "Expected redirect to process_saved_plan (got #{response.redirect_url})"
  end

  def test_mock_login_as_without_mock_data_returns_translated_alert
    OmniAuth.config.mock_auth[:developer] = nil

    get :mock_login_as, params: { user: 'developer' }

    assert_redirected_to root_path(locale: I18n.default_locale)
    assert_equal I18n.t('auth_test.mock_data_missing'), flash[:alert]
  end
end
