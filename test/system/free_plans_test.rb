# frozen_string_literal: true

require "application_system_test_case"

class FreePlansTest < ApplicationSystemTestCase
  setup do
    @region = Region.create!(name: "日本", country_code: "JP", active: true)
    @farm_size = FarmSize.create!(name: "小規模", area_sqm: 20, display_order: 1, active: true)
    @crop1 = Crop.create!(name: "トマト", variety: "大玉", is_reference: true, user_id: nil)
    @crop2 = Crop.create!(name: "ジャガイモ", variety: "男爵", is_reference: true, user_id: nil)
    @crop3 = Crop.create!(name: "玉ねぎ", variety: "黄玉ねぎ", is_reference: true, user_id: nil)
  end

  test "JavaScriptがロードされてカウンターが動作する" do
    # Step 1-2: 地域と農場サイズを選択
    visit new_free_plan_path
    click_on @region.name
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

  test "JavaScriptのupdate関数が存在する" do
    visit new_free_plan_path
    click_on @region.name
    click_on @farm_size.name
    
    # JavaScriptの関数が定義されているか
    script_result = page.evaluate_script("typeof update === 'function'")
    assert script_result, "update関数が定義されていません"
  end

  test "チェックボックスが正しくレンダリングされる" do
    visit new_free_plan_path
    click_on @region.name
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
    click_on @region.name
    click_on @farm_size.name
    
    # 必須要素の存在確認
    assert_selector "#counter", "カウンター要素が見つかりません"
    assert_selector "#submitBtn", "送信ボタンが見つかりません"
    assert_selector "#hint", "ヒント要素が見つかりません"
  end
end
