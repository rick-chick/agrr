# frozen_string_literal: true

require "application_system_test_case"

class MapInitializationErrorSystemTest < ApplicationSystemTestCase
  def setup
    @user = users(:one)
    @farm = farms(:one)
    @field = fields(:one)
  end

  test "地図の初期化でfield_latitudeがnullの場合のエラーを再現" do
    # ユーザーをログイン状態にする
    visit "/auth/test/mock_login_as/one" if Rails.env.development?
    
    # 新しい圃場作成ページにアクセス
    visit new_farm_field_path(@farm)
    
    # ページが正常に読み込まれることを確認
    assert_selector "h1", text: "新しい圃場を追加"
    assert_selector "input[name='field[latitude]']"
    assert_selector "input[name='field[longitude]']"
    
    # JavaScriptのエラーをキャッチするために、ブラウザのコンソールログを確認
    # 実際のエラーが発生するかどうかをテスト
    page.execute_script("
      // field_latitude要素を削除してエラーを再現
      const latElement = document.getElementById('field_latitude');
      if (latElement) {
        latElement.remove();
      }
      
      // initMap関数を呼び出してエラーを再現
      try {
        initMap();
      } catch (error) {
        console.error('Map initialization error:', error);
        window.mapInitError = error;
      }
    ")
    
    # エラーが発生したことを確認
    error = page.evaluate_script("window.mapInitError")
    assert_not_nil error, "地図の初期化エラーが発生するはずです"
    assert_includes error["message"], "Cannot read properties of null", "nullプロパティの読み取りエラーが発生するはずです"
  end

  test "地図の初期化でfield_longitudeがnullの場合のエラーを再現" do
    # ユーザーをログイン状態にする
    visit "/auth/test/mock_login_as/one" if Rails.env.development?
    
    # 新しい圃場作成ページにアクセス
    visit new_farm_field_path(@farm)
    
    # JavaScriptのエラーをキャッチするために、ブラウザのコンソールログを確認
    page.execute_script("
      // field_longitude要素を削除してエラーを再現
      const lngElement = document.getElementById('field_longitude');
      if (lngElement) {
        lngElement.remove();
      }
      
      // initMap関数を呼び出してエラーを再現
      try {
        initMap();
      } catch (error) {
        console.error('Map initialization error:', error);
        window.mapInitError = error;
      }
    ")
    
    # エラーが発生したことを確認
    error = page.evaluate_script("window.mapInitError")
    assert_not_nil error, "地図の初期化エラーが発生するはずです"
    assert_includes error["message"], "Cannot read properties of null", "nullプロパティの読み取りエラーが発生するはずです"
  end

  test "地図の初期化が正常に動作する場合" do
    # ユーザーをログイン状態にする
    visit "/auth/test/mock_login_as/one" if Rails.env.development?
    
    # 新しい圃場作成ページにアクセス
    visit new_farm_field_path(@farm)
    
    # 地図要素が存在することを確認
    assert_selector "#map"
    assert_selector "input[name='field[latitude]']"
    assert_selector "input[name='field[longitude]']"
    
    # JavaScriptのエラーがないことを確認
    page.execute_script("
      try {
        initMap();
        window.mapInitSuccess = true;
      } catch (error) {
        console.error('Map initialization error:', error);
        window.mapInitError = error;
      }
    ")
    
    # エラーが発生していないことを確認
    error = page.evaluate_script("window.mapInitError")
    success = page.evaluate_script("window.mapInitSuccess")
    
    assert_nil error, "地図の初期化でエラーが発生してはいけません"
    assert success, "地図の初期化が成功するはずです"
  end

  test "編集ページで地図の初期化が正常に動作する" do
    # ユーザーをログイン状態にする
    visit "/auth/test/mock_login_as/one" if Rails.env.development?
    
    # 圃場編集ページにアクセス
    visit edit_farm_field_path(@farm, @field)
    
    # 地図要素が存在し、緯度・経度の値が設定されていることを確認
    assert_selector "#map"
    assert_selector "input[name='field[latitude]'][value='#{@field.latitude}']"
    assert_selector "input[name='field[longitude]'][value='#{@field.longitude}']"
    
    # JavaScriptのエラーがないことを確認
    page.execute_script("
      try {
        initMap();
        window.mapInitSuccess = true;
      } catch (error) {
        console.error('Map initialization error:', error);
        window.mapInitError = error;
      }
    ")
    
    # エラーが発生していないことを確認
    error = page.evaluate_script("window.mapInitError")
    success = page.evaluate_script("window.mapInitSuccess")
    
    assert_nil error, "編集ページで地図の初期化エラーが発生してはいけません"
    assert success, "編集ページで地図の初期化が成功するはずです"
  end

  test "DOMContentLoadedイベントで地図が初期化される" do
    # ユーザーをログイン状態にする
    visit "/auth/test/mock_login_as/one" if Rails.env.development?
    
    # 新しい圃場作成ページにアクセス
    visit new_farm_field_path(@farm)
    
    # DOMContentLoadedイベントが発火するまで待機
    sleep 0.1
    
    # 地図が初期化されていることを確認
    map_initialized = page.evaluate_script("typeof map !== 'undefined' && map !== null")
    assert map_initialized, "DOMContentLoadedイベントで地図が初期化されるはずです"
  end
end
