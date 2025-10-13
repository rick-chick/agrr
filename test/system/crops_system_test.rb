# frozen_string_literal: true

require "application_system_test_case"

class CropsSystemTest < ApplicationSystemTestCase
  def setup
    @user = users(:two)  # 一般ユーザー
    @admin = users(:one) # 管理者ユーザー
  end

  test "visiting the crops index" do
    sign_in_as(@user)
    visit crops_path
    
    assert_selector "h1", text: "作物一覧"
    assert_selector "a", text: "新しい作物を追加"
  end

  test "creating a new crop" do
    sign_in_as(@user)
    visit crops_path
    
    click_on "新しい作物を追加"
    
    fill_in "名前", with: "システムテスト作物"
    fill_in "品種", with: "システムテスト品種"
    
    click_on "作物を作成"
    
    assert_text "作物が正常に作成されました"
    assert_text "システムテスト作物"
    assert_text "システムテスト品種"
  end

  test "editing a crop" do
    sign_in_as(@user)
    
    # Create a crop first
    crop = Crop.create!(
      name: "編集テスト作物",
      variety: "編集テスト品種",
      user_id: @user.id,
      is_reference: false
    )
    
    visit crops_path
    click_on "編集"
    
    fill_in "名前", with: "編集された作物"
    fill_in "品種", with: "編集された品種"
    
    click_on "作物を更新"
    
    assert_text "作物が正常に更新されました"
    assert_text "編集された作物"
    assert_text "編集された品種"
  end

  test "viewing crop details" do
    sign_in_as(@user)
    
    crop = Crop.create!(
      name: "詳細表示テスト",
      variety: "詳細表示品種",
      user_id: @user.id,
      is_reference: false
    )
    
    # Add a stage with requirements
    crop.crop_stages.create!(
      name: "発芽期",
      order: 1,
      temperature_requirement_attributes: {
        base_temperature: 10,
        optimal_min: 15,
        optimal_max: 25,
        low_stress_threshold: 5,
        high_stress_threshold: 30,
        frost_threshold: 0,
        sterility_risk_threshold: 35
      }
    )
    
    visit crop_path(crop)
    
    assert_text "詳細表示テスト"
    assert_text "詳細表示品種"
    assert_text "発芽期"
    assert_text "温度要件"
  end

  test "deleting a crop" do
    sign_in_as(@user)
    
    crop = Crop.create!(
      name: "削除テスト作物",
      user_id: @user.id,
      is_reference: false
    )
    
    visit crops_path
    
    accept_confirm do
      click_on "削除"
    end
    
    assert_text "作物が正常に削除されました"
    assert_no_text "削除テスト作物"
  end

  test "admin can create reference crops" do
    sign_in_as(@admin)
    visit crops_path
    
    click_on "新しい作物を追加"
    
    fill_in "名前", with: "参照作物"
    fill_in "品種", with: "参照品種"
    check "参照作物（管理者のみ）"
    
    click_on "作物を作成"
    
    assert_text "作物が正常に作成されました"
    assert_text "参照作物"
    assert_text "参照作物"
  end

  test "non-admin cannot create reference crops" do
    sign_in_as(@user)
    visit crops_path
    
    click_on "新しい作物を追加"
    
    fill_in "名前", with: "通常作物"
    
    # Checkbox should not be visible for non-admin
    assert_no_selector "#crop_is_reference", visible: :all
    
    # Create a normal crop
    click_on "作物を作成"
    
    assert_text "作物が正常に作成されました"
    
    # Verify it's not a reference crop
    crop = Crop.find_by(name: "通常作物")
    assert_not_nil crop
    assert_equal false, crop.is_reference
  end

  test "crop validation errors" do
    sign_in_as(@user)
    visit crops_path
    
    click_on "新しい作物を追加"
    
    # Submit without name
    click_on "作物を作成"
    
    assert_text "can't be blank"
  end

  test "crop type display for regular user" do
    # Create user crop
    user_crop = Crop.create!(
      name: "ユーザ作物",
      user_id: @user.id,
      is_reference: false
    )
    
    # Create reference crop
    ref_crop = Crop.create!(
      name: "参照作物",
      user_id: nil,
      is_reference: true
    )
    
    # Test as regular user - should only see their own crops
    sign_in_as(@user)
    visit crops_path
    
    assert_text "ユーザ作物"
    assert_no_text "参照作物"  # Regular users don't see reference crops
    assert_no_selector ".crop-type.reference"  # No reference badge visible
  end
  
  test "crop type display for admin" do
    # Create user crop
    user_crop = Crop.create!(
      name: "ユーザ作物",
      user_id: @admin.id,
      is_reference: false
    )
    
    # Create reference crop
    ref_crop = Crop.create!(
      name: "参照作物",
      user_id: nil,
      is_reference: true
    )
    
    # Test as admin - should see both
    sign_in_as(@admin)
    visit crops_path
    
    assert_text "ユーザ作物"
    assert_text "参照作物"
    
    # Admin should see reference badge for reference crop
    assert_selector ".crop-type.reference", text: "参照作物"
  end

  test "empty state display" do
    sign_in_as(@user)
    
    # Delete all crops first
    Crop.destroy_all
    
    visit crops_path
    
    assert_text "まだ作物が登録されていません"
    assert_text "最初の作物を追加して始めましょう"
    assert_selector "a", text: "作物を追加"
  end

  test "adding crop stages dynamically with JavaScript" do
    sign_in_as(@user)
    visit new_crop_path
    
    # Fill in basic crop information
    fill_in "名前", with: "テスト作物"
    fill_in "品種", with: "テスト品種"
    
    # Initially, there should be no crop stages
    assert_selector ".crop-stage-item", count: 0
    
    # Click the add crop stage button
    click_button "+ 生育ステージを追加"
    
    # A new crop stage should appear
    assert_selector ".crop-stage-item", count: 1
    
    # Fill in the first stage
    within first(".crop-stage-item") do
      fill_in "ステージ名", with: "発芽期"
      fill_in "順序", with: "0"
      
      # Fill in temperature requirements
      all("input[placeholder='例：5.0']").first.set("5.0")  # base_temperature
      all("input[placeholder='例：15.0']").first.set("15.0") # optimal_min
      all("input[placeholder='例：25.0']").first.set("25.0") # optimal_max
      all("input[placeholder='例：10.0']").first.set("10.0") # low_stress_threshold
      all("input[placeholder='例：30.0']").first.set("30.0") # high_stress_threshold
      all("input[placeholder='例：0.0']").first.set("0.0")   # frost_threshold
      all("input[placeholder='例：35.0']").first.set("35.0") # sterility_risk_threshold
      
      # Fill in sunshine requirements
      all("input[placeholder='例：4.0']").first.set("4.0")   # minimum_sunshine_hours
      all("input[placeholder='例：8.0']").first.set("8.0")   # target_sunshine_hours
    end
    
    # Add a second stage
    click_button "+ 生育ステージを追加"
    assert_selector ".crop-stage-item", count: 2
    
    # Fill in the second stage
    within all(".crop-stage-item").last do
      fill_in "ステージ名", with: "栄養成長期"
      fill_in "順序", with: "1"
    end
    
    # Submit the form
    click_button "作物を作成"
    
    # Verify crop was created with stages
    assert_text "作物が正常に作成されました"
    assert_text "テスト作物"
    assert_text "発芽期"
    assert_text "栄養成長期"
    
    # Verify temperature requirements are displayed
    assert_text "温度要件"
    assert_text "最低限界温度: 5.0°C"
    assert_text "最適温度: 15.0〜25.0°C"
    
    # Verify sunshine requirements are displayed
    assert_text "日照要件"
    assert_text "最低日照時間: 4.0時間"
    assert_text "目標日照時間: 8.0時間"
  end

  test "removing crop stages dynamically" do
    sign_in_as(@user)
    
    # Create a crop with existing stages
    crop = Crop.create!(
      name: "削除テスト作物",
      user_id: @user.id,
      is_reference: false
    )
    
    stage1 = crop.crop_stages.create!(name: "発芽期", order: 0)
    stage2 = crop.crop_stages.create!(name: "栄養成長期", order: 1)
    
    visit edit_crop_path(crop)
    
    # Both stages should be visible
    assert_selector ".crop-stage-item", count: 2
    assert_text "発芽期"
    assert_text "栄養成長期"
    
    # Remove the first stage
    within first(".crop-stage-item") do
      click_button "削除"
    end
    
    # The first stage should be hidden
    assert_selector ".crop-stage-item", visible: :all, count: 2
    assert_selector ".crop-stage-item", visible: :visible, count: 1
    
    # Submit the form
    click_button "作物を更新"
    
    assert_text "作物が正常に更新されました"
    
    # Verify the stage was deleted
    assert_no_text "発芽期"
    assert_text "栄養成長期"
  end

  test "adding new stages to existing crop" do
    sign_in_as(@user)
    
    # Create a crop with one existing stage
    crop = Crop.create!(
      name: "追加テスト作物",
      user_id: @user.id,
      is_reference: false
    )
    
    crop.crop_stages.create!(name: "発芽期", order: 0)
    
    visit edit_crop_path(crop)
    
    # One stage should exist
    assert_selector ".crop-stage-item", count: 1
    
    # Add a new stage
    click_button "+ 生育ステージを追加"
    
    # Two stages should be visible now
    assert_selector ".crop-stage-item", count: 2
    
    # Fill in the new stage
    within all(".crop-stage-item").last do
      fill_in "ステージ名", with: "開花期"
      fill_in "順序", with: "1"
    end
    
    # Submit the form
    click_button "作物を更新"
    
    assert_text "作物が正常に更新されました"
    
    # Verify both stages are present
    assert_text "発芽期"
    assert_text "開花期"
  end

  test "JavaScript functionality - button exists and is clickable" do
    sign_in_as(@user)
    visit new_crop_path
    
    # Verify the add button exists
    assert_selector "button#add-crop-stage", text: "+ 生育ステージを追加"
    
    # Verify the container exists
    assert_selector "#crop-stages"
    
    # The button should be clickable (not disabled)
    button = find("button#add-crop-stage")
    assert_not button.disabled?
  end
end
