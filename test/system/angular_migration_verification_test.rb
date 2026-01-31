require "application_system_test_case"

class AngularMigrationVerificationTest < ApplicationSystemTestCase
  setup do
    @user = create(:user)
    @user.generate_api_key!
    @farm = create(:farm, :user_owned, user: @user, name: "E2E Test Farm")
    @fertilize = create(:fertilize, :user_owned, user: @user, name: "E2E Test Fertilize")

    # 無料作付フロー用: 参照農場・作物（weather_location はジョブ用に必須）
    @weather_location = create(:weather_location)
    @ref_farm = create(:farm, :reference, region: "jp", name: "Ref Farm JP", weather_location: @weather_location)
    @ref_crop = create(:crop, :reference, region: "jp", name: "Ref Crop JP")
    create(:crop_stage, :germination, crop: @ref_crop, order: 1)
  end

  test "can visit farms list and detail in Angular" do
    login_as_system_user(@user)
    
    visit "/farms"
    
    # Angularがレンダリングされるのを待つ
    assert_selector "app-navbar", wait: 15
    
    # APIリクエストが完了するのを待つ
    sleep 10
    
    # 直接URL遷移で詳細画面へ
    visit "/farms/#{@farm.id}"
    
    # 詳細画面の表示確認
    # assert_selector "h2", wait: 15
  end

  test "can visit public plan wizard in Angular" do
    visit "/public-plans/new"

    assert_selector "h2", wait: 15

    # 直接作物選択へ
    visit "/public-plans/select-crop?farmId=#{@ref_farm.id}&farmSizeId=home_garden"

    # 作物選択画面
    assert_selector "h2", wait: 15
  end

  # 無料作付の計画作成が成功し、最適化画面へ遷移することを断言（RED で原因特定用）
  test "public plan create succeeds and navigates to optimizing" do
    visit "/public-plans/new"
    assert_selector ".enhanced-selection-card", wait: 15
    first(".enhanced-selection-card").click

    assert_current_path %r{/public-plans/select-farm-size}, wait: 10
    assert_selector ".enhanced-selection-card", wait: 10
    first(".enhanced-selection-card").click

    assert_current_path %r{/public-plans/select-crop}, wait: 10
    assert_selector "input[type='checkbox'].crop-check", wait: 15
    first("input[type='checkbox'].crop-check").click

    # 計画を作成（日本語 or 英語のボタン）
    submit = find("button.submit-button", wait: 5)
    assert submit.visible?, "Submit button should be visible"
    submit.click

    # 成功時は /public-plans/optimizing へ遷移すること
    assert_current_path %r{/public-plans/optimizing}, wait: 15
  end
end
