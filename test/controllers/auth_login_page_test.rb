# frozen_string_literal: true

require "test_helper"

class AuthLoginPageTest < ActionDispatch::IntegrationTest
  setup do
    # Ensure clean state for locale detection via Accept-Language header
    cookies.delete(:locale)
    I18n.locale = I18n.default_locale
  end

  test "renders login page with localized texts" do
    I18n.with_locale(:ja) do
      get auth_login_path

      assert_response :success
      assert_select "html[lang=ja]"
      assert_select 'meta[name="language"][content="ja"]'
      assert_select ".subtitle", I18n.t("auth.login.subtitle", locale: :ja)
      assert_includes response.body, I18n.t("auth.login.google_button", locale: :ja)
    end
  end

  test "renders login page in English when Accept-Language is en-US" do
    get "/auth/login", params: {}, env: { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9" }

    assert_response :success
    assert_select "html[lang=us]"
    assert_select 'meta[name="language"][content="us"]'
    assert_select ".subtitle", I18n.t("auth.login.subtitle", locale: :us)
    assert_includes response.body, I18n.t("auth.login.google_button", locale: :us)
  end
end
