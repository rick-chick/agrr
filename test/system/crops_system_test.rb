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
    
    fill_in "名前", with: "参照作物"
    # Checkbox should be disabled for non-admin
    ref_checkbox = find("#crop_is_reference", visible: false)
    assert ref_checkbox.disabled?
    
    # Try to submit anyway
    click_on "作物を作成"
    
    assert_text "参照作物は管理者のみ作成できます"
  end

  test "crop validation errors" do
    sign_in_as(@user)
    visit crops_path
    
    click_on "新しい作物を追加"
    
    # Submit without name
    click_on "作物を作成"
    
    assert_text "can't be blank"
  end

  test "crop type display" do
    sign_in_as(@user)
    
    # Create user crop
    user_crop = Crop.create!(
      name: "ユーザ作物",
      user_id: @user.id,
      is_reference: false
    )
    
    # Create reference crop
    ref_crop = Crop.create!(
      name: "参照作物",
      user_id: @admin.id,
      is_reference: true
    )
    
    visit crops_path
    
    assert_text "ユーザ作物"
    assert_text "参照作物"
    
    # Check type badges
    assert_selector ".crop-type.user", text: "ユーザ作物"
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
end
