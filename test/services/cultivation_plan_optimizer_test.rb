# frozen_string_literal: true

require 'test_helper'

class CultivationPlanOptimizerTest < ActiveSupport::TestCase
  def setup
    # アノニマスユーザーを作成
    @anonymous_user = User.create!(
      email: 'anonymous@agrr.app',
      name: 'Anonymous User',
      google_id: 'anonymous',
      is_anonymous: true
    )
    
    # 参照農場を作成
    @farm = Farm.create!(
      user: @anonymous_user,
      name: "テスト農場",
      latitude: 35.6812,
      longitude: 139.7671,
      is_reference: true
    )
    
    # WeatherLocationを作成
    @weather_location = WeatherLocation.create!(
      latitude: @farm.latitude,
      longitude: @farm.longitude,
      timezone: "Asia/Tokyo",
      elevation: 10.0
    )
    
    # 天気データを作成（過去20年分 + 今年）
    create_weather_data
    
    # 作物を作成
    @crop = Crop.create!(
      name: "トマト",
      variety: "桃太郎",
      is_reference: true,
      area_per_unit: 10.0,
      revenue_per_area: 5000.0
    )
    
    # 作物の生育ステージを作成
    stage1 = @crop.crop_stages.create!(name: "発芽期", order: 1)
    stage1.create_temperature_requirement!(
      base_temperature: 10.0,
      optimal_min: 20.0,
      optimal_max: 30.0
    )
    stage1.create_thermal_requirement!(required_gdd: 200.0)
    
    stage2 = @crop.crop_stages.create!(name: "開花期", order: 2)
    stage2.create_temperature_requirement!(
      base_temperature: 10.0,
      optimal_min: 22.0,
      optimal_max: 28.0
    )
    stage2.create_thermal_requirement!(required_gdd: 800.0)
    
    # 作付け計画を作成
    @cultivation_plan = CultivationPlan.create!(
      farm: @farm,
      total_area: 100.0,
      status: :pending
    )
    
    # 圃場と作物を作成
    plan_field = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: "テスト圃場",
      area: 100.0,
      daily_fixed_cost: 500.0
    )
    
    plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @cultivation_plan,
      name: @crop.name,
      variety: @crop.variety,
      agrr_crop_id: @crop.agrr_crop_id
    )
    
    @field_cultivation = FieldCultivation.create!(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      area: 100.0,
      status: :pending
    )
  end

  test "should raise WeatherDataNotFoundError when weather location not found" do
    # WeatherLocationを削除
    @weather_location.weather_data.destroy_all
    @weather_location.destroy!
    
    optimizer = CultivationPlanOptimizer.new(@cultivation_plan)
    
    # optimizerは内部でcatchしてfalseを返すので、raiseされない
    result = optimizer.call
    
    assert_equal false, result
    
    # 計画がfailedになることを確認
    @cultivation_plan.reload
    assert_equal 'failed', @cultivation_plan.status
    assert_match /Weather location not found/, @cultivation_plan.error_message
  end

  test "should raise WeatherDataNotFoundError when training data is empty" do
    # 天気データを全削除
    @weather_location.weather_data.destroy_all
    
    optimizer = CultivationPlanOptimizer.new(@cultivation_plan)
    
    # optimizerは内部でcatchしてfalseを返すので、raiseされない
    result = optimizer.call
    
    assert_equal false, result
    @cultivation_plan.reload
    assert_equal 'failed', @cultivation_plan.status
    assert_match /No training weather data found/, @cultivation_plan.error_message
  end

  test "should raise WeatherDataNotFoundError when training data is insufficient" do
    # 天気データを全削除して、100日分だけ作成（365日未満）
    @weather_location.weather_data.destroy_all
    
    # 100日分のデータを作成
    100.times do |i|
      WeatherDatum.create!(
        weather_location: @weather_location,
        date: Date.current - (i + 1).days,
        temperature_max: 20.0,
        temperature_min: 10.0,
        temperature_mean: 15.0,
        precipitation: 0.0,
        sunshine_hours: 8.0
      )
    end
    
    optimizer = CultivationPlanOptimizer.new(@cultivation_plan)
    result = optimizer.call
    
    assert_equal false, result
    @cultivation_plan.reload
    assert_equal 'failed', @cultivation_plan.status
    assert_match /Insufficient training weather data/, @cultivation_plan.error_message
    assert_match /100 records found/, @cultivation_plan.error_message
    assert_match /at least 365 days required/, @cultivation_plan.error_message
  end

  test "should raise WeatherDataNotFoundError when current year data is empty" do
    # 今年のデータだけ削除（過去20年分は残す）
    current_year_start = Date.new(Date.current.year, 1, 1)
    @weather_location.weather_data.where('date >= ?', current_year_start).destroy_all
    
    optimizer = CultivationPlanOptimizer.new(@cultivation_plan)
    
    # optimizerは内部でcatchしてfalseを返すので、raiseされない
    result = optimizer.call
    
    assert_equal false, result
    @cultivation_plan.reload
    assert_equal 'failed', @cultivation_plan.status
    assert_match /No current year weather data found/, @cultivation_plan.error_message
  end

  test "should handle prediction gateway error" do
    # PredictionGatewayがエラーを返す場合
    mock_gateway = Minitest::Mock.new
    mock_gateway.expect :predict, nil do |args|
      raise Agrr::BaseGateway::ParseError, "Prediction output file is empty"
    end
    
    Agrr::PredictionGateway.stub :new, mock_gateway do
      optimizer = CultivationPlanOptimizer.new(@cultivation_plan)
      result = optimizer.call
      
      assert_equal false, result
      @cultivation_plan.reload
      assert_equal 'failed', @cultivation_plan.status
      assert_match /Prediction output file is empty/, @cultivation_plan.error_message
    end
  end

  test "should handle optimization gateway error" do
    skip "Requires proper mocking of both gateways"
    # OptimizationGatewayがエラーを返す場合のテスト
  end

  test "should raise error when crop not found" do
    # Cropを削除
    @crop.destroy!
    
    optimizer = CultivationPlanOptimizer.new(@cultivation_plan)
    result = optimizer.call
    
    assert_equal false, result
    @cultivation_plan.reload
    assert_equal 'failed', @cultivation_plan.status
    # Cropが見つからない場合、または生育ステージがない場合のエラーメッセージ
    assert_match /(Crop not found|has no growth stages)/, @cultivation_plan.error_message
    assert_match /トマト/, @cultivation_plan.error_message
  end

  test "should adjust max_revenue based on revenue_per_area for equal area distribution" do
    # 重複する古い作物を削除（テストデータのクリーンアップ）
    Crop.where(name: ["トマト", "メロン", "レタス"]).where.not(id: @crop.id).destroy_all
    
    # 既存のトマトを確認（setup()で作成済み）
    @crop.reload
    assert_equal 2, @crop.crop_stages.count, "Tomato should have 2 growth stages"
    
    # データベースに保存されているか確認
    db_crop = Crop.includes(:crop_stages).find(@crop.id)
    assert_equal 2, db_crop.crop_stages.count, "Tomato in DB should have 2 growth stages"
    
    # 高収益作物を作成（トマトの2倍）
    high_revenue_crop = Crop.create!(
      name: "メロン",
      variety: "プリンス",
      is_reference: true,
      area_per_unit: 10.0,
      revenue_per_area: 10000.0  # トマトの2倍
    )
    
    # 生育ステージを作成
    stage1 = high_revenue_crop.crop_stages.create!(name: "発芽期", order: 1)
    stage1.create_temperature_requirement!(
      base_temperature: 10.0,
      optimal_min: 20.0,
      optimal_max: 30.0
    )
    stage1.create_thermal_requirement!(required_gdd: 200.0)
    
    stage2 = high_revenue_crop.crop_stages.create!(name: "開花期", order: 2)
    stage2.create_temperature_requirement!(
      base_temperature: 10.0,
      optimal_min: 22.0,
      optimal_max: 28.0
    )
    stage2.create_thermal_requirement!(required_gdd: 800.0)
    
    # 低収益作物を作成（トマトの半分）
    low_revenue_crop = Crop.create!(
      name: "レタス",
      variety: "サニー",
      is_reference: true,
      area_per_unit: 10.0,
      revenue_per_area: 2500.0  # トマトの半分
    )
    
    # 生育ステージを作成
    stage1_low = low_revenue_crop.crop_stages.create!(name: "発芽期", order: 1)
    stage1_low.create_temperature_requirement!(
      base_temperature: 5.0,
      optimal_min: 15.0,
      optimal_max: 25.0
    )
    stage1_low.create_thermal_requirement!(required_gdd: 150.0)
    
    stage2_low = low_revenue_crop.crop_stages.create!(name: "成長期", order: 2)
    stage2_low.create_temperature_requirement!(
      base_temperature: 5.0,
      optimal_min: 18.0,
      optimal_max: 23.0
    )
    stage2_low.create_thermal_requirement!(required_gdd: 350.0)
    
    # デフォルト収益作物（元々のトマト: 5000.0円/㎡）
    # revenue_per_areaが未設定なので5000.0がデフォルト値として使われる
    
    # 新しい圃場と作物を追加
    plan_field_high = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: "高収益圃場",
      area: 100.0,
      daily_fixed_cost: 500.0
    )
    
    plan_crop_high = CultivationPlanCrop.create!(
      cultivation_plan: @cultivation_plan,
      name: high_revenue_crop.name,
      variety: high_revenue_crop.variety
    )
    
    FieldCultivation.create!(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: plan_field_high,
      cultivation_plan_crop: plan_crop_high,
      area: 100.0,
      status: :pending
    )
    
    plan_field_low = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: "低収益圃場",
      area: 100.0,
      daily_fixed_cost: 500.0
    )
    
    plan_crop_low = CultivationPlanCrop.create!(
      cultivation_plan: @cultivation_plan,
      name: low_revenue_crop.name,
      variety: low_revenue_crop.variety
    )
    
    FieldCultivation.create!(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: plan_field_low,
      cultivation_plan_crop: plan_crop_low,
      area: 100.0,
      status: :pending
    )
    
    # prepare_allocation_dataを直接テスト
    optimizer = CultivationPlanOptimizer.new(@cultivation_plan)
    fields_data, crops_data, field_cultivation_map = optimizer.send(:prepare_allocation_data, Date.current + 1.year)
    
    # 3作物が作成されていることを確認
    assert_equal 3, crops_data.count
    
    # 平均 revenue_per_area = (5000 + 10000 + 2500) / 3 = 5833.33
    # 調整係数:
    #   トマト (5000): 5833.33 / 5000 = 1.167
    #   メロン (10000): 5833.33 / 10000 = 0.583
    #   レタス (2500): 5833.33 / 2500 = 2.333
    
    # 各作物のmax_revenueを確認
    tomato_crop = crops_data.find { |c| c['crop']['name'] == 'トマト' }
    melon_crop = crops_data.find { |c| c['crop']['name'] == 'メロン' }
    lettuce_crop = crops_data.find { |c| c['crop']['name'] == 'レタス' }
    
    assert_not_nil tomato_crop
    assert_not_nil melon_crop
    assert_not_nil lettuce_crop
    
    # max_revenueが調整されていることを確認
    # 高収益作物（メロン）のmax_revenueが抑えられている
    # 低収益作物（レタス）のmax_revenueが高くなっている
    # 調整後のmax_revenueは近い値になるはず
    
    tomato_max = tomato_crop['crop']['max_revenue']
    melon_max = melon_crop['crop']['max_revenue']
    lettuce_max = lettuce_crop['crop']['max_revenue']
    
    # メロンのmax_revenueがトマトより小さいか同程度であることを確認（高収益作物なので抑制）
    assert melon_max <= tomato_max * 1.2, "High revenue crop (melon) should have suppressed max_revenue"
    
    # レタスのmax_revenueがトマトより大きいか同程度であることを確認（低収益作物なので増強）
    assert lettuce_max >= tomato_max * 0.8, "Low revenue crop (lettuce) should have boosted max_revenue"
    
    # 3作物のmax_revenueが比較的近い値になっていることを確認（均等化の効果）
    max_values = [tomato_max, melon_max, lettuce_max]
    average_max = max_values.sum / max_values.size.to_f
    max_values.each do |val|
      deviation = (val - average_max).abs / average_max
      assert deviation < 0.5, "max_revenue values should be relatively close (within 50% deviation)"
    end
  end

  private

  def create_weather_data
    # 最低365日分のデータを作成（最低要件を満たす）
    # 過去2年分のデータを毎日作成
    start_date = Date.current - 2.years
    end_date = Date.current - 1.day
    
    (start_date..end_date).each do |date|
      WeatherDatum.create!(
        weather_location: @weather_location,
        date: date,
        temperature_max: 20.0 + rand(-10.0..10.0),
        temperature_min: 10.0 + rand(-10.0..5.0),
        temperature_mean: 15.0 + rand(-10.0..7.0),
        precipitation: rand(0.0..10.0),
        sunshine_hours: rand(0.0..12.0)
      )
    end
  end
end

