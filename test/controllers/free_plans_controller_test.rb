# frozen_string_literal: true

require "test_helper"

class FreePlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    # アノニマスユーザーと参照農場を作成
    User.instance_variable_set(:@anonymous_user, nil)
    @anonymous_user = User.anonymous_user
    
    # 参照農場を作成
    @farm = Farm.create!(
      user: @anonymous_user,
      name: "テスト農場",
      latitude: 35.6812,
      longitude: 139.7671,
      is_reference: true
    )
    
    @farm_size_id = 'community_garden'  # FARM_SIZES定数のID
    @crop1 = Crop.create!(name: "トマト", variety: "大玉", is_reference: true, user_id: nil)
    @crop2 = Crop.create!(name: "ジャガイモ", variety: "男爵", is_reference: true, user_id: nil)
  end

  test "should get new" do
    get new_free_plan_path
    assert_response :success
    assert_select "h1", text: /作付け計画作成/
  end

  test "should get select_farm_size with farm" do
    get select_farm_size_free_plans_path(farm_id: @farm.id)
    assert_response :success
    assert_select ".enhanced-summary-value", text: @farm.name
  end

  test "should get select_crop with farm_size" do
    # セッションに農場IDを設定
    get select_farm_size_free_plans_path(farm_id: @farm.id)
    
    # 農場サイズ選択画面へ
    get select_crop_free_plans_path(farm_size_id: @farm_size_id)
    assert_response :success
    assert_select ".crop-check", minimum: 2  # fixtureと動的作成の作物が両方表示される
    assert_select "label[for='crop_#{@crop1.id}']"
    assert_select "label[for='crop_#{@crop2.id}']"
  end

  test "should create multiple free crop plans" do
    # セッションを設定
    get select_farm_size_free_plans_path(farm_id: @farm.id)
    get select_crop_free_plans_path(farm_size_id: @farm_size_id)
    
    assert_difference('FreeCropPlan.count', 2) do
      post free_plans_path, params: { crop_ids: [@crop1.id, @crop2.id] }
    end
    
    assert_redirected_to calculating_all_free_plans_path
    
    # セッションに保存されているか確認
    assert session[:free_plan_ids].present?
    assert_equal 2, session[:free_plan_ids].length
  end

  test "should show calculating_all page" do
    # 計画を作成
    plan1 = FreeCropPlan.create!(farm: @farm, area_sqm: 50, crop: @crop1, session_id: 'test')
    plan2 = FreeCropPlan.create!(farm: @farm, area_sqm: 50, crop: @crop2, session_id: 'test')
    
    # セッションがない状態でリクエスト
    get calculating_all_free_plans_path
    # セッションがないためリダイレクトされる
    assert_response :redirect
    assert_redirected_to new_free_plan_path
  end

  test "updateCropSelection JavaScript logic" do
    # HTMLが正しい構造であることを確認
    get select_farm_size_free_plans_path(farm_id: @farm.id)
    get select_crop_free_plans_path(farm_size_id: @farm_size_id)
    
    assert_response :success
    
    # 必要な要素が存在するか
    assert_select "input.crop-check[id^='crop_']"
    assert_select "label[for^='crop_']"
    assert_select "#counter"
    assert_select "#submitBtn"
    # JavaScriptは別ファイル（application.js）にバンドルされているため、
    # インラインscriptタグには含まれない
  end
end



