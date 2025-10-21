# frozen_string_literal: true

require "test_helper"

class PublicPlanCreationTest < ActionDispatch::IntegrationTest
  def setup
    @anonymous_user = User.create!(
      email: 'anonymous@agrr.app',
      name: 'Anonymous User',
      google_id: 'anonymous',
      is_anonymous: true
    )
    
    @farm = Farm.create!(
      user: @anonymous_user,
      name: "北海道・札幌",
      latitude: 43.0642,
      longitude: 141.3469,
      is_reference: true
    )
    
    @weather_location = WeatherLocation.create!(
      latitude: @farm.latitude,
      longitude: @farm.longitude,
      timezone: "Asia/Tokyo",
      elevation: 10.0
    )
    
    create_weather_data
    
    @crop1 = Crop.create!(
      name: "トマト",
      variety: "桃太郎",
      is_reference: true
    )
    
    @crop2 = Crop.create!(
      name: "キュウリ",
      variety: "夏すずみ",
      is_reference: true
    )
  end
  
  test "complete flow: select region, farm size, crops and create plan" do
    # Step 1: 栽培地域選択画面を表示
    get public_plans_path
    assert_response :success
    
    # Step 2: 農場サイズ選択画面へ
    get select_farm_size_public_plans_path(farm_id: @farm.id)
    assert_response :success
    assert_select ".content-card-title", text: /農場のサイズを選択/
    
    # Step 3: 作物選択画面へ
    get select_crop_public_plans_path(farm_size_id: 'home_garden')
    assert_response :success
    assert_select ".content-card-title", text: /栽培したい作物を選択/
    assert_select ".crop-card", minimum: 2
    
    # Step 4: 作物を選択して計画作成
    assert_difference 'CultivationPlan.count', 1 do
      post public_plans_path, params: {
        crop_ids: [@crop1.id, @crop2.id]
      }
    end
    
    # 最適化画面にリダイレクト
    assert_redirected_to optimizing_public_plans_path
    
    # 計画が作成されていることを確認
    plan = CultivationPlan.last
    assert_equal @farm.id, plan.farm_id
    assert_equal 30.0, plan.total_area # home_gardenは30㎡
    assert_equal 'pending', plan.status
    
    # 計画に作物が含まれている
    assert plan.cultivation_plan_crops.any?
    assert plan.cultivation_plan_fields.any?
  end
  
  test "cannot create plan without selecting crops" do
    setup_session_with_farm_size('home_garden')
    
    assert_no_difference 'CultivationPlan.count' do
      post public_plans_path, params: { crop_ids: [] }
    end
    
    assert_redirected_to select_crop_public_plans_path
    assert_equal '作物を1つ以上選択してください。', flash[:alert]
  end
  
  test "cannot create plan without session data" do
    reset!
    
    assert_no_difference 'CultivationPlan.count' do
      post public_plans_path, params: { crop_ids: [@crop1.id] }
    end
    
    assert_redirected_to public_plans_path
  end
  
  test "crop selection page displays correctly" do
    setup_session_with_farm_size('home_garden')
    
    assert_response :success
    
    # 作物が表示されている
    assert_select ".crop-name", text: "トマト"
    assert_select ".crop-name", text: "キュウリ"
    
    # フォーム要素
    assert_select "form#cropForm" do
      assert_select "input[type='checkbox'][name='crop_ids[]'][value='#{@crop1.id}']"
      assert_select "input[type='checkbox'][name='crop_ids[]'][value='#{@crop2.id}']"
      assert_select "input.crop-check", minimum: 1
    end
    
    # ボトムバー
    assert_select ".fixed-bottom-bar" do
      assert_select "#counter"
      assert_select "#submitBtn[disabled]"
      assert_select "#hint"
    end
    
    assert_select "button[type='submit'][form='cropForm']", text: /選択した作物で計画を作成/
  end
  
  test "displays correct farm info for different farm sizes" do
    get select_farm_size_public_plans_path(farm_id: @farm.id)
    get select_crop_public_plans_path(farm_size_id: 'community_garden')
    
    assert_response :success
    assert_select ".enhanced-summary-value", text: /#{@farm.name}/
    assert_select ".enhanced-summary-value", text: /市民農園/
    assert_select ".enhanced-summary-value", text: /50㎡/
  end
  
  private
  
  def setup_session_with_farm_size(farm_size_id)
    get select_farm_size_public_plans_path(farm_id: @farm.id)
    get select_crop_public_plans_path(farm_size_id: farm_size_id)
  end
  
  def create_weather_data
    # バルクインサートで高速化（730回のINSERT → 1回のINSERT）
    weather_data_records = []
    now = Time.current
    
    [2024, 2025].each do |year|
      (Date.new(year, 1, 1)..Date.new(year, 12, 31)).each do |date|
        weather_data_records << {
          weather_location_id: @weather_location.id,
          date: date,
          temperature_max: 20.0 + rand(-5.0..10.0),
          temperature_min: 10.0 + rand(-5.0..5.0),
          temperature_mean: 15.0 + rand(-5.0..7.0),
          precipitation: rand(0.0..10.0),
          sunshine_hours: rand(0.0..12.0),
          created_at: now,
          updated_at: now
        }
      end
    end
    
    WeatherDatum.insert_all(weather_data_records) if weather_data_records.any?
  end
end

