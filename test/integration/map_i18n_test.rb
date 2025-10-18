# frozen_string_literal: true

require "test_helper"

class MapI18nTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  # 地図のdata属性 - 日本語
  test "should have Japanese map data attributes in farm new" do
    get new_farm_path(locale: :ja)
    assert_response :success
    
    # 地図要素にdata属性があるべき
    assert_select "#map[data-farm-location]"
    assert_select "#map[data-map-library-load-failed]"
    assert_select "#map[data-map-load-failed]"
    assert_select "#map[data-reload-page]"
    assert_select "#map[data-retry]"
    assert_select "#map[data-map-loading]"
  end

  # 地図のdata属性 - 英語
  test "should have English map data attributes in farm new" do
    get new_farm_path(locale: :us)
    assert_response :success
    
    # 地図要素にdata属性があるべき
    assert_select "#map[data-farm-location]"
    assert_select "#map[data-map-library-load-failed]"
    assert_select "#map[data-map-load-failed]"
    assert_select "#map[data-reload-page]"
    assert_select "#map[data-retry]"
    assert_select "#map[data-map-loading]"
  end

  # 地図のdata属性 - 日本語 (Edit)
  test "should have Japanese map data attributes in farm edit" do
    farm = Farm.create!(name: "Test Farm", user: @user, latitude: 35.6762, longitude: 139.6503)
    
    get edit_farm_path(farm, locale: :ja)
    assert_response :success
    
    assert_select "#map[data-farm-location]"
  end

  # 地図のdata属性 - 英語 (Edit)
  test "should have English map data attributes in farm edit" do
    farm = Farm.create!(name: "Test Farm", user: @user, latitude: 35.6762, longitude: 139.6503)
    
    get edit_farm_path(farm, locale: :us)
    assert_response :success
    
    assert_select "#map[data-farm-location]"
  end
end

