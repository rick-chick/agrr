# frozen_string_literal: true

require "test_helper"

class Api::V1::PublicPlans::CultivationPlansAdjustTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @farm = farms(:one)
    @farm.update!(
      weather_location: "東京",
      latitude: 35.6762,
      longitude: 139.6503
    )
    
    # 栽培計画を作成
    @cultivation_plan = CultivationPlan.create!(
      name: "テスト計画",
      farm: @farm,
      user: @user,
      planning_start_date: Date.new(2025, 10, 19),
      planning_end_date: Date.new(2026, 12, 31),
      status: :optimized,
      optimization_result: {
        total_profit: 1000.0,
        total_cost: 2500.0,
        total_revenue: 3500.0
      },
      predicted_weather_data: {
        latitude: 35.6762,
        longitude: 139.6503,
        data: (Date.new(2025, 10, 19)..Date.new(2026, 12, 31)).map do |date|
          {
            time: date.to_s,
            temperature_2m_max: 20.0,
            temperature_2m_min: 10.0,
            temperature_2m_mean: 15.0
          }
        end
      }
    )
    
    # 圃場を作成
    @field1 = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: "圃場1",
      area: 150.0,
      daily_fixed_cost: 10.0
    )
    
    @field2 = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: "圃場2",
      area: 150.0,
      daily_fixed_cost: 10.0
    )
    
    # 参照作物を取得
    @crop = crops(:spinach)
    
    # 栽培計画作物を作成
    @plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @cultivation_plan,
      name: @crop.name,
      variety: @crop.variety,
      agrr_crop_id: @crop.id.to_s
    )
    
    # 圃場栽培を作成
    @cultivation = FieldCultivation.create!(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: @field1,
      cultivation_plan_crop: @plan_crop,
      start_date: Date.new(2026, 7, 2),
      completion_date: Date.new(2026, 9, 19),
      area: 150.0,
      estimated_cost: 500.0,
      optimization_result: {
        revenue: 0.0,
        profit: -500.0,
        accumulated_gdd: 0.0
      }
    )
  end
  
  test "adjust endpoint successfully processes move request" do
    # 移動指示を送信
    post api_v1_public_plans_cultivation_plan_adjust_path(@cultivation_plan),
      params: {
        moves: [
          {
            allocation_id: "alloc_#{@cultivation.id}",
            action: "move",
            to_field_id: "field_#{@field2.id}",
            to_start_date: "2026-07-15"
          }
        ]
      },
      as: :json
    
    # レスポンスを確認
    assert_response :success, "Response: #{response.body}"
    
    json = JSON.parse(response.body)
    assert json['success'], "Expected success: true, got: #{json.inspect}"
    assert_equal @cultivation_plan.id, json['cultivation_plan']['id']
    
    puts "✅ Adjust endpoint test passed"
  end
  
  test "adjust endpoint handles invalid field_id" do
    # 存在しない圃場IDで移動指示を送信
    post api_v1_public_plans_cultivation_plan_adjust_path(@cultivation_plan),
      params: {
        moves: [
          {
            allocation_id: "alloc_#{@cultivation.id}",
            action: "move",
            to_field_id: "field_999999",
            to_start_date: "2026-07-15"
          }
        ]
      },
      as: :json
    
    # エラーレスポンスを確認
    assert_response :internal_server_error
    
    json = JSON.parse(response.body)
    assert_equal false, json['success']
    assert_not_nil json['message']
    
    puts "✅ Invalid field_id test passed"
  end
  
  test "adjust endpoint requires moves parameter" do
    # movesなしでリクエスト
    post api_v1_public_plans_cultivation_plan_adjust_path(@cultivation_plan),
      params: {},
      as: :json
    
    # エラーレスポンスを確認
    assert_response :bad_request
    
    json = JSON.parse(response.body)
    assert_equal false, json['success']
    assert_match /移動指示がありません/, json['message']
    
    puts "✅ Missing moves parameter test passed"
  end
end

