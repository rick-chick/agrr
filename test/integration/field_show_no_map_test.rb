# frozen_string_literal: true

require "test_helper"

class FieldShowNoMapTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @farm = @user.farms.create!(name: "テスト農場")
    @field = @farm.fields.create!(name: "テスト圃場", user: @user)
  end

  test "圃場詳細ページで地図関連のメソッドが削除されていることを確認" do
    # 圃場詳細ページにアクセス
    get farm_field_path(@farm, @field)
    assert_response :success
    
    # レスポンスに地図関連の情報が含まれていないことを確認
    assert_not_includes response.body, "緯度"
    assert_not_includes response.body, "経度"
    assert_not_includes response.body, "位置情報"
    assert_not_includes response.body, "has_coordinates"
    
    # 圃場名は表示されていることを確認
    assert_includes response.body, "テスト圃場"
  end

  test "Fieldモデルにhas_coordinates?メソッドが存在しないことを確認" do
    # Fieldモデルインスタンスでhas_coordinates?メソッドが存在しないことを確認
    assert_not @field.respond_to?(:has_coordinates?)
  end

  test "Fieldモデルにlatitudeメソッドが存在しないことを確認" do
    # Fieldモデルインスタンスでlatitudeメソッドが存在しないことを確認
    assert_not @field.respond_to?(:latitude)
  end

  test "Fieldモデルにlongitudeメソッドが存在しないことを確認" do
    # Fieldモデルインスタンスでlongitudeメソッドが存在しないことを確認
    assert_not @field.respond_to?(:longitude)
  end

  test "Fieldモデルにcoordinatesメソッドが存在しないことを確認" do
    # Fieldモデルインスタンスでcoordinatesメソッドが存在しないことを確認
    assert_not @field.respond_to?(:coordinates)
  end

  test "圃場一覧ページで地図関連の情報が表示されないことを確認" do
    # 圃場一覧ページにアクセス
    get farm_fields_path(@farm)
    assert_response :success
    
    # レスポンスに地図関連の情報が含まれていないことを確認
    assert_not_includes response.body, "緯度"
    assert_not_includes response.body, "経度"
    assert_not_includes response.body, "位置情報が設定されていません"
    
    # 圃場名は表示されていることを確認
    assert_includes response.body, "テスト圃場"
  end
end
