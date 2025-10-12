# frozen_string_literal: true

require "application_system_test_case"

class CropSelectionBrokenTest < ApplicationSystemTestCase
  setup do
    @region = Region.create!(name: "日本", country_code: "JP", active: true)
    @farm_size = FarmSize.create!(name: "小規模", area_sqm: 20, display_order: 1, active: true)
    @crop1 = Crop.create!(name: "トマト", variety: "大玉", is_reference: true, user_id: nil)
    @crop2 = Crop.create!(name: "ジャガイモ", variety: "男爵", is_reference: true, user_id: nil)
  end

  test "問題の再現: 作物を選択してもカウンターが増えない" do
    # 作物選択画面まで進む
    visit new_free_plan_path
    click_on @region.name
    click_on @farm_size.name
    
    # 初期状態確認
    counter = find("#counter")
    submit_btn = find("#submitBtn")
    
    puts "\n=== 初期状態 ==="
    puts "カウンター表示: #{counter.text}"
    puts "ボタンdisabled: #{submit_btn.disabled?}"
    
    # カードをクリック
    first_label = find("label[for='crop_#{@crop1.id}']")
    puts "\n=== カードをクリック ==="
    first_label.click
    
    sleep 1
    
    # 問題: カウンターが増えていない
    puts "カウンター表示: #{counter.text}"
    puts "期待値: 1"
    puts "実際: #{counter.text}"
    
    # このassertは失敗するはず（問題を再現）
    assert_equal "1", counter.text, "❌ 問題再現: カウンターが増えていない"
    
    # 問題: ボタンが有効にならない
    puts "ボタンdisabled: #{submit_btn.disabled?}"
    puts "期待値: false (有効)"
    
    # このassertも失敗するはず（問題を再現）
    assert_not submit_btn.disabled?, "❌ 問題再現: ボタンが有効にならない"
  end
end



