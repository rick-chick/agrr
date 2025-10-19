# frozen_string_literal: true

require "test_helper"

class Api::V1::PublicPlans::CultivationPlansAddCropTest < ActionDispatch::IntegrationTest
  include AgrrMockHelper
  
  setup do
    @user = users(:one)
    @farm = farms(:one)
    
    # WeatherLocationを作成
    @weather_location = WeatherLocation.find_or_create_by_coordinates(
      latitude: @farm.latitude,
      longitude: @farm.longitude,
      timezone: 'Asia/Tokyo'
    )
    
    # FarmにWeatherLocationを関連付け
    @farm.update!(weather_location: @weather_location)
    
    # 気象データを作成（最小限、毎日のデータ）
    # GDD計算には毎日のデータが必要
    start_date = Date.current
    end_date = Date.current + 120.days
    (start_date..end_date).each do |date|
      WeatherDatum.create!(
        weather_location: @weather_location,
        date: date,
        temperature_max: 25.0,
        temperature_min: 15.0,
        temperature_mean: 20.0,
        precipitation: 0.0
      )
    end
    
    # 参照作物を作成
    @crop = Crop.create!(
      name: 'トマト',
      variety: '桃太郎',
      is_reference: true,
      region: 'jp',
      area_per_unit: 1.0,
      revenue_per_area: 5000.0,
      agrr_crop_id: 'トマト'
    )
    
    # 作物ステージを作成
    stage1 = @crop.crop_stages.create!(name: '発芽', order: 1)
    stage1.create_temperature_requirement!(
      base_temperature: 10.0,
      optimal_min: 15.0,
      optimal_max: 25.0,
      low_stress_threshold: 10.0,
      high_stress_threshold: 30.0,
      frost_threshold: 5.0,
      max_temperature: 35.0
    )
    stage1.create_thermal_requirement!(required_gdd: 100.0)
    
    stage2 = @crop.crop_stages.create!(name: '成長', order: 2)
    stage2.create_temperature_requirement!(
      base_temperature: 10.0,
      optimal_min: 18.0,
      optimal_max: 28.0,
      low_stress_threshold: 12.0,
      high_stress_threshold: 32.0,
      frost_threshold: 5.0,
      max_temperature: 35.0
    )
    stage2.create_thermal_requirement!(required_gdd: 300.0)
    
    stage3 = @crop.crop_stages.create!(name: '収穫', order: 3)
    stage3.create_temperature_requirement!(
      base_temperature: 10.0,
      optimal_min: 20.0,
      optimal_max: 30.0,
      low_stress_threshold: 15.0,
      high_stress_threshold: 35.0,
      frost_threshold: 5.0,
      max_temperature: 38.0
    )
    stage3.create_thermal_requirement!(required_gdd: 500.0)
    
    # 栽培計画を作成
    planning_end_date = Date.current + 120.days
    @cultivation_plan = CultivationPlan.create!(
      farm: @farm,
      total_area: 50.0,
      status: 'completed',
      planning_start_date: Date.current,
      planning_end_date: planning_end_date,
      predicted_weather_data: {
        'latitude' => @farm.latitude,
        'longitude' => @farm.longitude,
        'timezone' => 'Asia/Tokyo',
        'data' => (start_date..end_date).map do |date|
          {
            'time' => date.to_s,
            'temperature_2m_max' => 25.0,
            'temperature_2m_min' => 15.0,
            'temperature_2m_mean' => 20.0,
            'precipitation_sum' => 0.0
          }
        end
      }
    )
    
    # 圃場を作成
    @field = @cultivation_plan.cultivation_plan_fields.create!(
      name: '圃場1',
      area: 25.0,
      daily_fixed_cost: 0.0
    )
  end
  
  test "should add crop with valid parameters" do
    # AGRR CLIをモック化（AgrrMockHelperを使用）
    mock_agrr_cli_success
    
    assert_difference 'FieldCultivation.count', 1 do
      assert_difference 'CultivationPlanCrop.count', 1 do
        post add_crop_api_v1_public_plans_cultivation_plan_url(
          @cultivation_plan,
          locale: 'ja'
        ), params: {
          crop_id: @crop.id,
          field_id: "field_#{@field.id}",
          start_date: (Date.current + 30.days).to_s
        }, as: :json
      end
    end
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal true, json_response['success']
    assert json_response['cultivation_plan'].present?
  end
  
  test "should return error when crop not found" do
    post add_crop_api_v1_public_plans_cultivation_plan_url(
      @cultivation_plan,
      locale: 'ja'
    ), params: {
      crop_id: 99999,
      field_id: "field_#{@field.id}",
      start_date: (Date.current + 30.days).to_s
    }, as: :json
    
    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal false, json_response['success']
  end
  
  test "should return error when field not found" do
    post add_crop_api_v1_public_plans_cultivation_plan_url(
      @cultivation_plan,
      locale: 'ja'
    ), params: {
      crop_id: @crop.id,
      field_id: "field_99999",
      start_date: (Date.current + 30.days).to_s
    }, as: :json
    
    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal false, json_response['success']
    assert_match(/圃場が見つかりません/, json_response['message'])
  end
  
  test "should return error when weather data not available" do
    # 気象予測データを削除
    @cultivation_plan.update!(predicted_weather_data: nil)
    
    post add_crop_api_v1_public_plans_cultivation_plan_url(
      @cultivation_plan,
      locale: 'ja'
    ), params: {
      crop_id: @crop.id,
      field_id: "field_#{@field.id}",
      start_date: (Date.current + 30.days).to_s
    }, as: :json
    
    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal false, json_response['success']
    assert_match(/気象予測データがありません/, json_response['message'])
  end
  
  test "should estimate cultivation days based on GDD" do
    # GDD推定は公開インターフェース（add_crop API）経由で間接的にテスト
    # AGRR CLIをモック化
    mock_agrr_cli_success
    
    post add_crop_api_v1_public_plans_cultivation_plan_url(
      @cultivation_plan,
      locale: 'ja'
    ), params: {
      crop_id: @crop.id,
      field_id: "field_#{@field.id}",
      start_date: (Date.current + 30.days).to_s
    }, as: :json
    
    assert_response :success
    
    # 作成された栽培レコードを確認
    cultivation = FieldCultivation.last
    
    # トマトの総GDD要件: 100 + 300 + 500 = 900
    # 平均日別GDD: 20 - 10 = 10℃
    # 予想栽培日数: 90日程度（モックの結果による）
    assert_not_nil cultivation
    assert cultivation.cultivation_days > 0
  end
end

