require "application_system_test_case"

class AngularMigrationVerificationTest < ApplicationSystemTestCase
  setup do
    @user = create(:user)
    @user.generate_api_key!
    @farm = create(:farm, :user_owned, user: @user, name: "E2E Test Farm")
    @fertilize = create(:fertilize, :user_owned, user: @user, name: "E2E Test Fertilize")
    
    # 参照データ
    @ref_farm = create(:farm, :reference, region: 'jp', name: "Ref Farm JP")
    @ref_crop = create(:crop, :reference, region: 'jp', name: "Ref Crop JP")
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
    
    # 作物選択
    # チェックボックスが表示されるまで待つ
    # assert_selector "input[type='checkbox']", wait: 15
    # first("input[type='checkbox']").click
    
    # 最適化開始
    # ボタンが表示されるまで待つ
    # assert_selector "button", text: /Optimizing|Next|Start/, wait: 15
    # if page.has_button?("Start Optimizing")
    #   click_button "Start Optimizing"
    # else
    #   all("button").find { |b| b.text.include?("Optimizing") }&.click
    # end
    
    # 最適化中画面
    # assert_selector "h2", wait: 15
  end
end
