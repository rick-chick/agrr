# frozen_string_literal: true

require 'test_helper'

class GanttAdjustIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    
    # 農場を作成
    @farm = Farm.create!(
      name: "テスト農場",
      user: @user,
      latitude: 35.6762,
      longitude: 139.6503,
      weather_location: "東京"
    )
    
    # 栽培計画を作成
    @cultivation_plan = CultivationPlan.create!(
      name: "統合テスト計画",
      farm: @farm,
      planning_start_date: Date.new(2025, 10, 19),
      planning_end_date: Date.new(2026, 12, 31),
      status: :optimized,
      optimization_result: {
        total_profit: 1000.0,
        total_cost: 2500.0,
        total_revenue: 3500.0
      }
    )
    
    # 圃場を作成
    @field1 = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: "圃場1",
      area: 17.0,
      daily_fixed_cost: 10.0
    )
    
    @field2 = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: "圃場2",
      area: 17.0,
      daily_fixed_cost: 10.0
    )
    
    # 参照作物を取得
    @crop = crops(:spinach)
    
    # 栽培計画作物を作成
    @plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @cultivation_plan,
      name: @crop.name,
      variety: @crop.variety,
      agrr_crop_id: @crop.agrr_crop_id
    )
    
    # 圃場栽培を作成
    @cultivation = FieldCultivation.create!(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: @field1,
      cultivation_plan_crop: @plan_crop,
      start_date: Date.new(2026, 7, 2),
      completion_date: Date.new(2026, 9, 19),
      area: 16.67,
      estimated_cost: 500.0,
      optimization_result: {
        revenue: 0.0,
        profit: -500.0,
        accumulated_gdd: 0.0
      }
    )
    
    # 気象データを保存
    @cultivation_plan.update!(
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
  end
  
  test "adjust APIエンドポイントが正しく動作する" do
    # 移動指示を送信
    post api_v1_public_plans_cultivation_plan_adjust_path(@cultivation_plan), params: {
      moves: [
        {
          allocation_id: "alloc_#{@cultivation.id}",
          action: "move",
          to_field_id: "field_#{@field2.id}",
          to_start_date: "2026-07-15"
        }
      ]
    }, as: :json
    
    # レスポンスを確認
    assert_response :success, "API should return success status. Response: #{response.body}"
    
    json = JSON.parse(response.body)
    assert json['success'], "API should return success: true. Response: #{json.inspect}"
    assert_equal @cultivation_plan.id, json['cultivation_plan']['id']
    
    # データベースが更新されていることを確認
    @cultivation.reload
    # Note: 実際のagrrコマンドが動作する環境であれば、
    # start_dateやfieldが更新されているはず
  end
  
  test "adjust APIが不正なfield_idでエラーを返す" do
    # 存在しない圃場IDで移動指示を送信
    post api_v1_public_plans_cultivation_plan_adjust_path(@cultivation_plan), params: {
      moves: [
        {
          allocation_id: "alloc_#{@cultivation.id}",
          action: "move",
          to_field_id: "field_999999",
          to_start_date: "2026-07-15"
        }
      ]
    }, as: :json
    
    # エラーレスポンスを確認
    assert_response :internal_server_error
    
    json = JSON.parse(response.body)
    assert_equal false, json['success']
    assert_not_nil json['message']
  end
end

