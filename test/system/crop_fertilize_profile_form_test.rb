# frozen_string_literal: true

require "application_system_test_case"

class CropFertilizeProfileFormTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(
      email: 'crop_fertilize_profile_test@example.com',
      name: 'Crop Fertilize Profile Test User',
      google_id: "crop_fertilize_profile_#{SecureRandom.hex(8)}"
    )
    
    login_as_system_user(@user)
    
    @crop = create(:crop, :tomato, user: @user)
  end

  test "施用計画追加ボタンが表示される" do
    visit new_crop_crop_fertilize_profile_path(@crop)
    
    # 追加ボタンが存在することを確認
    assert_selector '#add-crop-fertilize-application', wait: 5
    button = find('#add-crop-fertilize-application')
    assert button.present?, "追加ボタンが表示されていません"
    assert_not button.disabled?, "ボタンが無効になっています"
  end

  test "追加ボタンを1回クリックすると施用計画が1つだけ追加される" do
    visit new_crop_crop_fertilize_profile_path(@crop)
    
    # 初期状態では施用計画は0個
    application_items = page.all('.crop-fertilize-application-item', visible: :all)
    initial_count = application_items.length
    
    # 追加ボタンを1回クリック
    add_button = find('#add-crop-fertilize-application')
    add_button.click
    
    # 施用計画が1つだけ追加されることを確認
    sleep 0.3 # JavaScriptの処理を待つ
    application_items = page.all('.crop-fertilize-application-item', visible: :all)
    assert_equal initial_count + 1, application_items.length, "施用計画が1つだけ追加されるべき"
  end

  test "追加ボタンを複数回クリックしても重複登録されない（イベントリスナー重複防止）" do
    visit new_crop_crop_fertilize_profile_path(@crop)
    
    # 初期状態を確認
    application_items = page.all('.crop-fertilize-application-item', visible: :all)
    initial_count = application_items.length
    
    # 追加ボタンを連続して5回クリック（重複登録がなければ、それぞれ1つずつ追加される）
    add_button = find('#add-crop-fertilize-application')
    5.times do |i|
      add_button.click
      sleep 0.2 # 各クリック後に少し待つ
      
      # クリック回数分だけ追加されていることを確認
      application_items = page.all('.crop-fertilize-application-item', visible: :all)
      expected_count = initial_count + i + 1
      assert_equal expected_count, application_items.length, 
        "#{i + 1}回目のクリック後に#{expected_count}個の施用計画があるべき（重複登録されていない）"
    end
  end

  test "Turbo遷移後も追加ボタンが正しく動作する" do
    # まずプロファイルを作成
    profile = create(:crop_fertilize_profile, crop: @crop)
    
    # 編集画面にアクセス（Turbo遷移をシミュレート）
    visit edit_crop_crop_fertilize_profile_path(@crop, profile)
    
    # 追加ボタンが存在することを確認
    assert_selector '#add-crop-fertilize-application', wait: 5
    
    # 追加ボタンをクリック
    application_items = page.all('.crop-fertilize-application-item', visible: :all)
    initial_count = application_items.length
    
    add_button = find('#add-crop-fertilize-application')
    add_button.click
    
    sleep 0.3
    application_items = page.all('.crop-fertilize-application-item', visible: :all)
    assert_equal initial_count + 1, application_items.length, 
      "Turbo遷移後も追加ボタンが正しく動作する"
  end

  test "追加した施用計画を削除できる" do
    visit new_crop_crop_fertilize_profile_path(@crop)
    
    # 施用計画を1つ追加
    add_button = find('#add-crop-fertilize-application')
    add_button.click
    sleep 0.3
    
    # 削除ボタンをクリック
    remove_button = page.first('.remove-crop-fertilize-application')
    assert_not_nil remove_button, "削除ボタンが表示されていません"
    
    remove_button.click
    sleep 0.2
    
    # 施用計画が削除されることを確認（新規追加の場合は完全に削除される）
    application_items = page.all('.crop-fertilize-application-item', visible: :all)
    # 削除ボタンで非表示になっている可能性があるが、DOMから削除されるか非表示になる
    visible_items = page.all('.crop-fertilize-application-item', visible: true)
    assert_equal 0, visible_items.length, "施用計画が削除されるべき"
  end

  test "既存の施用計画を削除すると_destroyフラグが立つ" do
    # 既存のプロファイルと施用計画を作成
    profile = create(:crop_fertilize_profile, crop: @crop)
    application = create(:crop_fertilize_application, :basal, crop_fertilize_profile: profile)
    
    visit edit_crop_crop_fertilize_profile_path(@crop, profile)
    
    # 削除ボタンをクリック
    remove_button = page.first('.remove-crop-fertilize-application')
    remove_button.click
    sleep 0.2
    
    # _destroyフラグが立っていることを確認（hidden inputのvalueが'1'になっている）
    destroy_flag = page.first('.destroy-flag', visible: :all)
    assert_not_nil destroy_flag, "_destroyフラグが存在しない"
    assert_equal '1', destroy_flag.value, "_destroyフラグが'1'に設定されるべき"
    
    # 施用計画が非表示になっていることを確認
    application_item = page.first('.crop-fertilize-application-item')
    assert_not_nil application_item, "施用計画の要素が存在する"
    # display: noneが設定されているか確認
    assert_equal 'none', application_item.native.css_value('display'), "施用計画が非表示になるべき"
  end
end

