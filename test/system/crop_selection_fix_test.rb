# frozen_string_literal: true

require "application_system_test_case"

class CropSelectionFixTest < ApplicationSystemTestCase
  setup do
    @region = Region.create!(name: "日本", country_code: "JP", active: true)
    @farm_size = FarmSize.create!(name: "小規模", area_sqm: 20, display_order: 1, active: true)
    @crop1 = Crop.create!(name: "トマト", variety: "大玉", is_reference: true, user_id: nil)
    @crop2 = Crop.create!(name: "ジャガイモ", variety: "男爵", is_reference: true, user_id: nil)
  end

  test "作物選択でカウンターが増えてボタンが有効になる" do
    visit new_free_plan_path
    click_on @region.name
    click_on @farm_size.name
    
    # 初期状態
    assert_selector "#counter", text: "0"
    
    # カードをクリック
    find("label[for='crop_#{@crop1.id}']").click
    
    sleep 0.5
    
    # カウンターが1になる
    assert_selector "#counter", text: "1"
    
    # ボタンが有効になる
    submit_btn = find("#submitBtn")
    assert_not submit_btn.disabled?
  end
end



