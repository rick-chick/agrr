# frozen_string_literal: true

require "test_helper"

class FieldsFlowTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_authenticated_user
  end

  test "complete field creation and management flow" do
    # 1. 圃場一覧ページにアクセス
    get fields_path
    assert_response :success
    assert_select "h1", "圃場一覧"
    
    # 空の状態を確認
    assert_select ".empty-state"
    
    # 2. 新しい圃場作成ページにアクセス
    get new_field_path
    assert_response :success
    assert_select "h1", "新しい圃場を追加"
    
    # フォーム要素の存在確認
    assert_select "form[action='#{fields_path}'][method='post']"
    assert_select "input[name='field[name]']"
    assert_select "input[name='field[latitude]']"
    assert_select "input[name='field[longitude]']"
    
    # 地図コンテナの存在確認
    assert_select "#map"
    assert_select ".map-container"
    
    # Leafletの読み込み確認
    assert_select "link[href='/leaflet.css']"
    assert_select "script[src='/leaflet.js']"
    
    # 3. 圃場を作成
    field_name = "テスト圃場"
    latitude = 35.6812
    longitude = 139.7671
    
    assert_difference('Field.count') do
      post fields_path, params: {
        field: {
          name: field_name,
          latitude: latitude,
          longitude: longitude
        }
      }
    end
    
    # 作成後のリダイレクト確認
    assert_redirected_to field_path(Field.last)
    follow_redirect!
    
    # 成功メッセージの確認
    assert_select ".alert", "圃場が正常に作成されました。"
    
    # 4. 圃場詳細ページの確認
    field = Field.last
    assert_select "h1", field.display_name
    assert_select ".field-name", field_name
    assert_select ".info-value", latitude.to_s
    assert_select ".info-value", longitude.to_s
    
    # 5. 圃場一覧に戻る
    get fields_path
    assert_response :success
    
    # 圃場が表示されていることを確認
    assert_select ".fields-grid"
    assert_select ".field-card"
    assert_select ".field-name", field_name
    
    # 6. 圃場編集ページにアクセス
    get edit_field_path(field)
    assert_response :success
    assert_select "h1", "圃場を編集"
    
    # フォームに既存の値が設定されていることを確認
    assert_select "input[name='field[name]'][value='#{field_name}']"
    assert_select "input[name='field[latitude]'][value='#{latitude}']"
    assert_select "input[name='field[longitude]'][value='#{longitude}']"
    
    # 地図が表示されていることを確認
    assert_select "#map"
    
    # 7. 圃場情報を更新
    new_name = "更新された圃場"
    new_latitude = 36.2048
    new_longitude = 138.2529
    
    patch field_path(field), params: {
      field: {
        name: new_name,
        latitude: new_latitude,
        longitude: new_longitude
      }
    }
    
    # 更新後のリダイレクト確認
    assert_redirected_to field_path(field)
    follow_redirect!
    
    # 成功メッセージの確認
    assert_select ".alert", "圃場が正常に更新されました。"
    
    # 更新された内容の確認
    field.reload
    assert_equal new_name, field.name
    assert_equal new_latitude, field.latitude
    assert_equal new_longitude, field.longitude
    
    # 8. 圃場を削除
    assert_difference('Field.count', -1) do
      delete field_path(field)
    end
    
    # 削除後のリダイレクト確認
    assert_redirected_to fields_path
    follow_redirect!
    
    # 成功メッセージの確認
    assert_select ".alert", "圃場が削除されました。"
    
    # 9. 圃場一覧で空の状態を確認
    assert_select ".empty-state"
    assert_select ".empty-state-icon", "🌾"
  end

  test "field creation with invalid data" do
    # 無効なデータで圃場作成を試行
    assert_no_difference('Field.count') do
      post fields_path, params: {
        field: {
          name: "", # 空の名前
          latitude: 200, # 無効な緯度
          longitude: 200 # 無効な経度
        }
      }
    end
    
    # エラーレスポンスの確認
    assert_response :unprocessable_entity
    
    # エラーメッセージの確認
    assert_select ".error"
  end

  test "user can only access their own fields" do
    # 別のユーザーを作成
    other_user = User.create!(
      email: 'other@example.com',
      name: 'Other User',
      google_id: "google_#{SecureRandom.hex(8)}"
    )
    
    # 別のユーザーの圃場を作成
    other_field = Field.create!(
      user: other_user,
      name: "Other Field",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    # 別のユーザーの圃場にアクセスできないことを確認
    get field_path(other_field)
    assert_redirected_to fields_path
    follow_redirect!
    assert_select ".alert", "指定された圃場が見つかりません。"
    
    get edit_field_path(other_field)
    assert_redirected_to fields_path
    follow_redirect!
    assert_select ".alert", "指定された圃場が見つかりません。"
    
    # 削除もできないことを確認
    assert_no_difference('Field.count') do
      delete field_path(other_field)
    end
    assert_redirected_to fields_path
  end

  test "field name uniqueness per user" do
    field_name = "ユニークな圃場名"
    
    # 最初の圃場を作成
    assert_difference('Field.count') do
      post fields_path, params: {
        field: {
          name: field_name,
          latitude: 35.6812,
          longitude: 139.7671
        }
      }
    end
    
    # 同じ名前で別の圃場を作成しようとする
    assert_no_difference('Field.count') do
      post fields_path, params: {
        field: {
          name: field_name, # 同じ名前
          latitude: 36.2048,
          longitude: 138.2529
        }
      }
    end
    
    # エラーレスポンスの確認
    assert_response :unprocessable_entity
  end

  test "map functionality in forms" do
    # 新規作成フォームで地図が表示されることを確認
    get new_field_path
    assert_response :success
    
    # 地図コンテナと関連要素の確認
    assert_select "#map"
    assert_select ".map-container"
    assert_select ".coordinates-input"
    
    # 編集フォームで地図が表示されることを確認
    field = Field.create!(
      user: @user,
      name: "テスト圃場",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    get edit_field_path(field)
    assert_response :success
    
    # 地図コンテナと関連要素の確認
    assert_select "#map"
    assert_select ".map-container"
    assert_select ".coordinates-input"
    
    # 既存の座標値がフォームに設定されていることを確認
    assert_select "input[name='field[latitude]'][value='35.6812']"
    assert_select "input[name='field[longitude]'][value='139.7671']"
  end
end
