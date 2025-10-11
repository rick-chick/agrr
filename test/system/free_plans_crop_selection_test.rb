# frozen_string_literal: true

require "application_system_test_case"

class FreePlansCropSelectionTest < ApplicationSystemTestCase
  setup do
    @region = Region.create!(name: "日本", country_code: "JP", active: true)
    @farm_size = FarmSize.create!(name: "小規模", area_sqm: 20, display_order: 1, active: true)
    @crop1 = Crop.create!(name: "トマト", variety: "大玉", is_reference: true, user_id: nil)
    @crop2 = Crop.create!(name: "ジャガイモ", variety: "男爵", is_reference: true, user_id: nil)
  end

  test "E2E: 作物選択画面でJavaScriptが動作する" do
    # Step 1: 地域選択
    visit new_free_plan_path
    assert_selector "h1", text: "作付け計画作成"
    click_on @region.name
    
    # Step 2: 農場サイズ選択
    assert_current_path select_farm_size_free_plans_path(region_id: @region.id)
    click_on @farm_size.name
    
    # Step 3: 作物選択画面
    assert_current_path select_crop_free_plans_path(farm_size_id: @farm_size.id)
    
    # 必須要素の存在確認
    assert_selector "#counter", text: "0"
    assert_selector "#submitBtn[disabled]"
    assert_selector "#hint", text: "作物を1つ以上選択してください"
    
    # チェックボックスとラベルの存在確認
    assert_selector ".crop-check", visible: false, count: 2
    assert_selector "label[for='crop_#{@crop1.id}']"
    assert_selector "label[for='crop_#{@crop2.id}']"
    
    # ラベルをクリック（1つ目）
    first_label = find("label[for='crop_#{@crop1.id}']")
    first_label.click
    sleep 1
    
    # カウンターが1になっているか
    counter = find("#counter")
    assert_equal "1", counter.text, "カウンターが1になっていない。実際: '#{counter.text}'"
    
    # ボタンが有効になっているか
    submit_button = find("#submitBtn")
    assert_not submit_button.disabled?, "ボタンがまだdisabled"
    
    # ヒントが消えているか
    hint = find("#hint", visible: false)
    assert_not hint.visible?, "ヒントが表示されたまま"
    
    # 2つ目のラベルをクリック
    second_label = find("label[for='crop_#{@crop2.id}']")
    second_label.click
    sleep 0.5
    
    # カウンターが2になっているか
    assert_equal "2", counter.text, "カウンターが2になっていない。実際: '#{counter.text}'"
    
    # 1つ目を再度クリック（解除）
    first_label.click
    sleep 0.5
    
    # カウンターが1に戻っているか
    assert_equal "1", counter.text, "カウンターが1に戻っていない。実際: '#{counter.text}'"
    
    # ボタンはまだ有効
    assert_not submit_button.disabled?
    
    puts "✅ E2Eテスト成功: JavaScriptが正しく動作しています"
  end

  test "E2E: チェックボックスの状態とCSSが連動する" do
    visit new_free_plan_path
    click_on @region.name
    click_on @farm_size.name
    
    # 初期状態: カードは未選択
    first_checkbox = find("#crop_#{@crop1.id}", visible: false)
    first_label = find("label[for='crop_#{@crop1.id}']")
    
    # カードをクリック
    first_label.click
    sleep 0.5
    
    # チェックボックスがチェックされているか
    assert first_checkbox.checked?, "チェックボックスがチェックされていない"
    
    # CSSの:checkedスタイルが適用されているか（背景色確認）
    # Capybaraでは直接CSSを確認できないが、要素の存在は確認できる
    assert_selector ".crop-check:checked", visible: false, count: 1
  end

  test "E2E: JavaScriptのコンソールログを確認" do
    visit new_free_plan_path
    click_on @region.name
    click_on @farm_size.name
    
    # ブラウザのコンソールログを取得
    logs = page.driver.browser.logs.get(:browser)
    log_text = logs.map(&:message).join("\n")
    
    # 期待されるログが含まれているか
    assert log_text.include?("free_plans.js loaded") || 
           log_text.include?("Found") || 
           log_text.include?("checkboxes"),
           "JavaScriptがロードされていません。ログ: #{log_text}"
    
    puts "📋 コンソールログ:"
    puts log_text
  end

  test "E2E: ボタンのカーソルスタイルが正しく変わる" do
    visit new_free_plan_path
    click_on @region.name
    click_on @farm_size.name
    
    submit_button = find("#submitBtn")
    
    # 初期状態: cursor: not-allowed
    initial_cursor = submit_button.native.css_value('cursor')
    assert_equal "not-allowed", initial_cursor, "初期状態のカーソルが not-allowed でない"
    
    # 作物を選択
    first_label = find("label[for='crop_#{@crop1.id}']")
    first_label.click
    sleep 1
    
    # ボタンが有効になった後: cursor: pointer
    enabled_cursor = submit_button.native.css_value('cursor')
    assert_equal "pointer", enabled_cursor, "有効状態のカーソルが pointer でない。実際: '#{enabled_cursor}'"
    
    # 作物を解除
    first_label.click
    sleep 1
    
    # ボタンが無効になった後: cursor: not-allowed
    disabled_cursor = submit_button.native.css_value('cursor')
    assert_equal "not-allowed", disabled_cursor, "無効状態のカーソルが not-allowed に戻っていない。実際: '#{disabled_cursor}'"
    
    puts "✅ カーソルスタイルテスト成功: 状態に応じて正しく変化しています"
  end
end

