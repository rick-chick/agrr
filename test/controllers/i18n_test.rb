# frozen_string_literal: true

require "test_helper"

class I18nTest < ActionDispatch::IntegrationTest
  test "should default to Japanese locale" do
    get root_path
    assert_response :success
    assert_equal :ja, I18n.locale
  end
  
  test "should switch to English locale via URL parameter" do
    get root_path(locale: :en)
    assert_response :success
    assert_equal :en, I18n.locale
  end
  
  test "should persist locale in cookies" do
    get root_path(locale: :en)
    assert_equal "en", cookies[:locale]
    
    # 次のリクエストでもlocaleが維持される
    get about_path
    assert_equal :en, I18n.locale
  end
  
  test "should display Japanese navigation" do
    get root_path(locale: :ja)
    assert_response :success
    assert_select ".navbar-brand", text: /AGRR/
  end
  
  test "should display English navigation" do
    get root_path(locale: :en)
    assert_response :success
    assert_select ".navbar-brand", text: /AGRR/
  end
  
  test "should display Japanese home page content" do
    get root_path(locale: :ja)
    assert_response :success
    assert_select "h1.hero-title", text: /農業をもっとスマートに/
  end
  
  test "should display English home page content" do
    get root_path(locale: :en)
    assert_response :success
    assert_select "h1.hero-title", text: /Make Agriculture Smarter/
  end
  
  test "should display Japanese public plans page" do
    get public_plans_path(locale: :ja)
    assert_response :success
    assert_select "h2.content-card-title", text: /栽培地域を選択してください/
  end
  
  test "should display English public plans page" do
    get public_plans_path(locale: :en)
    assert_response :success
    assert_select "h2.content-card-title", text: /Select Your Growing Region/
  end
  
  test "should fallback to default locale for invalid locale" do
    get root_path(locale: "invalid")
    assert_equal :ja, I18n.locale
  end
  
  test "should include locale in generated URLs" do
    get root_path(locale: :en)
    assert_select "a[href*='locale=en']"
  end
end

