# frozen_string_literal: true

require "test_helper"

class AuthLoginPageTest < ActionDispatch::IntegrationTest
  test "renders login page with localized texts" do
    I18n.with_locale(:ja) do
      get auth_login_path

      assert_response :success
      assert_select ".subtitle", I18n.t('auth.login.subtitle', locale: :ja)
      assert_includes response.body, I18n.t('auth.login.google_button', locale: :ja)
    end
  end

  test "renders login page in English when Accept-Language is en-US" do
    get "/auth/login", headers: { 'Accept-Language' => 'en-US,en;q=0.9' }

    assert_response :success
    assert_select ".subtitle", I18n.t('auth.login.subtitle', locale: :us)
    assert_includes response.body, I18n.t('auth.login.google_button', locale: :us)
  end
end

