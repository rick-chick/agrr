# frozen_string_literal: true

require "application_system_test_case"

class FreePlansTest < ApplicationSystemTestCase
  setup do
    # Regionモデルは削除されたため、デフォルト農場を作成
    anonymous_user = User.anonymous_user
    @farm = Farm.create!(
      user: anonymous_user,
      name: "日本（東京）",
      latitude: 35.6812,
      longitude: 139.7671,
      is_default: true
    )
    # fixtureの農場サイズと作物を使用
    @farm_size = farm_sizes(:small)
    @crop1 = crops(:tomato)
    @crop2 = crops(:cucumber)
    @crop3 = crops(:lettuce)
  end

  test "JavaScriptがロードされてカウンターが動作する" do
    # Step 1-2: 地域と農場サイズを選択
    visit new_free_plan_path
    click_on @farm.name
    click_on @farm_size.name
    
    # Step 3: 作物選択画面
    assert_current_path select_crop_free_plans_path(farm_size_id: @farm_size.id)
    
    # JavaScriptの初期化を待つ
    sleep 1
    
    # 初期状態: カウンターが0
    counter = find("#counter")
    assert_equal "0", counter.text
    
    # 初期状態: ボタンがdisabled
    submit_button = find("#submitBtn")
    assert submit_button.disabled?
    
    # コンソールログを確認（JavaScriptがロードされたか）
    logs = page.driver.browser.logs.get(:browser)
    log_messages = logs.map(&:message).join("\n")
    
    assert log_messages.include?("Found"), "JavaScriptが初期化されていません: #{log_messages}"
    
    # 作物カードをクリック
    first_checkbox = find("#crop_#{@crop1.id}", visible: false)
    first_label = find("label[for='crop_#{@crop1.id}']")
    
    # ラベルをクリック
    first_label.click
    
    # JavaScriptの実行を待つ
    sleep 0.5
    
    # チェックボックスがチェックされているか
    assert first_checkbox.checked?, "チェックボックスがチェックされていません"
    
    # カウンターが1になっているか
    assert_equal "1", counter.text, "カウンターが更新されていません。実際: #{counter.text}"
    
    # ボタンが有効になっているか
    assert_not submit_button.disabled?, "ボタンが有効になっていません"
    
    # 2つ目をクリック
    second_label = find("label[for='crop_#{@crop2.id}']")
    second_label.click
    sleep 0.5
    
    # カウンターが2になっているか
    assert_equal "2", counter.text, "カウンターが2になっていません。実際: #{counter.text}"
    
    # もう一度1つ目をクリック（解除）
    first_label.click
    sleep 0.5
    
    # カウンターが1に戻っているか
    assert_equal "1", counter.text, "カウンターが減っていません。実際: #{counter.text}"
    
    # まだボタンは有効
    assert_not submit_button.disabled?
  end

  # Note: JavaScriptはIIFEでカプセル化されているため、直接関数をテストできない
  # 代わりに、「JavaScriptがロードされてカウンターが動作する」テストで機能を検証
  # test "JavaScriptのupdate関数が存在する" - スキップ（カプセル化されたプライベート関数のため）

  test "チェックボックスが正しくレンダリングされる" do
    visit new_free_plan_path
    click_on @farm.name
    click_on @farm_size.name
    
    # チェックボックスの数
    checkboxes = all(".crop-check", visible: false)
    assert_equal 3, checkboxes.count, "チェックボックスが3つありません。実際: #{checkboxes.count}"
    
    # ラベルの数
    labels = all("label[for^='crop_']")
    assert_equal 3, labels.count, "ラベルが3つありません。実際: #{labels.count}"
    
    # for属性が正しく設定されているか
    labels.each_with_index do |label, index|
      for_attr = label[:for]
      assert for_attr.present?, "Label #{index} にfor属性がありません"
      assert for_attr.start_with?("crop_"), "for属性が正しくありません: #{for_attr}"
    end
  end

  test "カウンターとボタンの要素が存在する" do
    visit new_free_plan_path
    click_on @farm.name
    click_on @farm_size.name
    
    # 必須要素の存在確認
    assert_selector "#counter"
    assert_selector "#submitBtn"
    assert_selector "#hint"
  end
end
