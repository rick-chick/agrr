# frozen_string_literal: true

require "application_system_test_case"

class FieldShowNoMapSystemTest < ApplicationSystemTestCase
  def setup
    @user = users(:one)
    @farm = @user.farms.create!(name: "テスト農場")
    @field = @farm.fields.create!(name: "テスト圃場", user: @user)
    
    # ユーザーとしてログイン
    visit root_path
    click_on "ログイン"
  end

  test "圃場詳細ページが地図機能なしで正常に表示される" do
    # 農場一覧から圃場詳細ページに移動
    visit farms_path
    click_on @farm.display_name
    click_on "圃場一覧"
    click_on @field.display_name
    
    # ページが正常に表示されることを確認
    assert_selector "h1", text: @field.display_name
    
    # 圃場名が表示されることを確認
    assert_text "テスト圃場"
    
    # 地図関連の要素が表示されていないことを確認
    assert_no_text "緯度"
    assert_no_text "経度"
    assert_no_text "位置情報"
    
    # 編集ボタンが表示されることを確認
    assert_selector "a", text: "編集"
  end

  test "圃場作成ページが地図機能なしで正常に表示される" do
    # 農場一覧から圃場作成ページに移動
    visit farms_path
    click_on @farm.display_name
    click_on "圃場一覧"
    click_on "新しい圃場"
    
    # ページが正常に表示されることを確認
    assert_selector "h1", text: "新しい圃場を追加"
    
    # 圃場名入力フィールドが表示されることを確認
    assert_selector "input[name='field[name]']"
    
    # 地図関連の要素が表示されていないことを確認
    assert_no_selector "#map"
    assert_no_selector "input[name='field[latitude]']"
    assert_no_selector "input[name='field[longitude]']"
  end

  test "圃場編集ページが地図機能なしで正常に表示される" do
    # 圃場詳細ページから編集ページに移動
    visit farm_field_path(@farm, @field)
    click_on "編集"
    
    # ページが正常に表示されることを確認
    assert_selector "h1", text: "圃場を編集"
    
    # 圃場名入力フィールドが表示されることを確認
    assert_selector "input[name='field[name]']"
    assert_field "field[name]", with: @field.name
    
    # 地図関連の要素が表示されていないことを確認
    assert_no_selector "#map"
    assert_no_selector "input[name='field[latitude]']"
    assert_no_selector "input[name='field[longitude]']"
  end

  test "圃場一覧ページが地図機能なしで正常に表示される" do
    # 圃場一覧ページに移動
    visit farm_fields_path(@farm)
    
    # ページが正常に表示されることを確認
    assert_selector "h1", text: "圃場一覧"
    
    # 圃場名が表示されることを確認
    assert_text "テスト圃場"
    
    # 地図関連の要素が表示されていないことを確認
    assert_no_text "緯度"
    assert_no_text "経度"
    assert_no_text "位置情報"
    
    # 新しい圃場を追加ボタンが表示されることを確認
    assert_selector "a", text: "新しい圃場を追加"
  end
end
