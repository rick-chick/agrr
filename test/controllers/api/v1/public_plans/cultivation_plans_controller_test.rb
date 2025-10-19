# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    module PublicPlans
      class CultivationPlansControllerTest < ActionDispatch::IntegrationTest
        setup do
          # 参照農場を作成
          @farm = farms(:tokyo_reference)
          
          # 天気ロケーションを作成
          @weather_location = WeatherLocation.create!(
            farm: @farm,
            latitude: @farm.latitude,
            longitude: @farm.longitude,
            timezone: 'Asia/Tokyo'
          )
          
          # 作付け計画を作成
          @cultivation_plan = CultivationPlan.create!(
            farm: @farm,
            total_area: 100.0,
            planning_start_date: Date.current,
            planning_end_date: Date.current + 6.months,
            status: 'completed',
            optimization_result: {
              'optimization_id' => 'test_opt_001',
              'total_profit' => 50000.0
            },
            predicted_weather_data: {
              'latitude' => @farm.latitude,
              'longitude' => @farm.longitude,
              'data' => []
            }
          )
          
          # 圃場を追加
          @field1 = @cultivation_plan.cultivation_plan_fields.create!(
            name: '圃場 1',
            area: 50.0
          )
          @field2 = @cultivation_plan.cultivation_plan_fields.create!(
            name: '圃場 2',
            area: 50.0
          )
          
          # 作物を追加
          @crop1 = @cultivation_plan.cultivation_plan_crops.create!(
            agrr_crop_id: 'tomato',
            name: 'トマト',
            variety: '桃太郎',
            area_per_unit: 1.0,
            revenue_per_area: 10000.0,
            max_revenue: 100000.0,
            groups: ['Solanaceae']
          )
          
          # 栽培スケジュールを追加
          @cultivation1 = FieldCultivation.create!(
            cultivation_plan: @cultivation_plan,
            cultivation_plan_field: @field1,
            cultivation_plan_crop: @crop1,
            start_date: Date.current + 1.month,
            completion_date: Date.current + 3.months,
            cultivation_days: 60,
            area: 25.0,
            estimated_cost: 5000.0,
            optimization_result: {
              'revenue' => 25000.0,
              'cost' => 5000.0,
              'profit' => 20000.0
            }
          )
        end
        
        test 'adjust returns error when no moves provided' do
          post adjust_api_v1_public_plans_cultivation_plan_path(@cultivation_plan),
               params: { moves: [] },
               as: :json
          
          assert_response :bad_request
          json = JSON.parse(response.body)
          assert_equal false, json['success']
          assert_includes json['message'], '移動指示がありません'
        end
        
        test 'adjust endpoint exists and accepts moves' do
          # Gatewayのモックを作成（実際のコマンドは実行しない）
          mock_gateway = Minitest::Mock.new
          mock_result = {
            optimization_id: 'test_opt_002',
            total_profit: 48000.0,
            field_schedules: [],
            raw: {}
          }
          mock_gateway.expect :adjust, mock_result, [Hash]
          
          Agrr::AdjustGateway.stub :new, mock_gateway do
            moves = [
              {
                allocation_id: "alloc_#{@cultivation1.id}",
                action: 'move',
                to_field_id: "field_#{@field2.id}",
                to_start_date: (Date.current + 2.months).to_s
              }
            ]
            
            post adjust_api_v1_public_plans_cultivation_plan_path(@cultivation_plan),
                 params: { moves: moves },
                 as: :json
            
            # ゲートウェイが呼ばれていればOK（実際の実行は統合テストで確認）
            # ここではエンドポイントの存在とパラメータの受け取りのみを確認
          end
          
          mock_gateway.verify
        end
      end
    end
  end
end

