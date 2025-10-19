# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    module PublicPlans
      class CultivationPlansControllerTest < ActionDispatch::IntegrationTest
        setup do
          # 参照農場を作成
          @farm = farms(:test_farm)
          
          # 天気ロケーションを作成
          @weather_location = WeatherLocation.find_or_create_by_coordinates(
            latitude: @farm.latitude,
            longitude: @farm.longitude,
            timezone: 'Asia/Tokyo'
          )
          
          # Farmに天気ロケーションを設定
          @farm.update!(weather_location: @weather_location)
          
          # 作付け計画を作成
          @cultivation_plan = CultivationPlan.create!(
            farm: @farm,
            total_area: 100.0,
            planning_start_date: Date.current,
            planning_end_date: Date.current + 6.months,
            status: 'completed',
            optimization_summary: {
              'optimization_id' => 'test_opt_001'
            },
            total_profit: 50000.0,
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
            revenue_per_area: 10000.0
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
          post adjust_api_v1_public_plans_cultivation_plan_path(id: @cultivation_plan.id, locale: nil),
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
            
            post adjust_api_v1_public_plans_cultivation_plan_path(id: @cultivation_plan.id, locale: nil),
                 params: { moves: moves },
                 as: :json
            
            # ゲートウェイが呼ばれていればOK（実際の実行は統合テストで確認）
            # ここではエンドポイントの存在とパラメータの受け取りのみを確認
          end
          
          mock_gateway.verify
        end
        
        test 'add_field creates new field successfully' do
          assert_difference '@cultivation_plan.cultivation_plan_fields.count', 1 do
            post add_field_api_v1_public_plans_cultivation_plan_path(id: @cultivation_plan.id, locale: nil),
                 params: { field_name: '圃場 3', field_area: 75.0 },
                 as: :json
          end
          
          assert_response :success
          json = JSON.parse(response.body)
          assert_equal true, json['success']
          assert_equal '圃場を追加しました', json['message']
          assert_equal '圃場 3', json['field']['name']
          assert_equal 75.0, json['field']['area']
          
          # 合計面積が更新されているか確認
          @cultivation_plan.reload
          assert_equal 175.0, @cultivation_plan.total_area
        end
        
        test 'add_field uses default values when not provided' do
          initial_count = @cultivation_plan.cultivation_plan_fields.count
          
          post add_field_api_v1_public_plans_cultivation_plan_path(id: @cultivation_plan.id, locale: nil),
               as: :json
          
          assert_response :success
          json = JSON.parse(response.body)
          assert_equal true, json['success']
          assert_includes json['field']['name'], '圃場'
          assert_equal 100.0, json['field']['area']
        end
        
        test 'add_field returns error for invalid area' do
          post add_field_api_v1_public_plans_cultivation_plan_path(id: @cultivation_plan.id, locale: nil),
               params: { field_name: '圃場 3', field_area: -10.0 },
               as: :json
          
          assert_response :bad_request
          json = JSON.parse(response.body)
          assert_equal false, json['success']
          assert_includes json['message'], '面積'
        end
        
        test 'remove_field deletes empty field successfully' do
          # 空の圃場（field2）を削除
          field_id = "field_#{@field2.id}"
          
          assert_difference '@cultivation_plan.cultivation_plan_fields.count', -1 do
            delete remove_field_api_v1_public_plans_cultivation_plan_path(id: @cultivation_plan.id, field_id: field_id, locale: nil),
                   as: :json
          end
          
          assert_response :success
          json = JSON.parse(response.body)
          assert_equal true, json['success']
          assert_equal '圃場を削除しました', json['message']
          
          # 合計面積が更新されているか確認
          @cultivation_plan.reload
          assert_equal 50.0, @cultivation_plan.total_area
        end
        
        test 'remove_field returns error for field with cultivations' do
          # cultivation1がある field1 を削除しようとする
          field_id = "field_#{@field1.id}"
          
          delete remove_field_api_v1_public_plans_cultivation_plan_path(id: @cultivation_plan.id, field_id: field_id, locale: nil),
                 as: :json
          
          assert_response :bad_request
          json = JSON.parse(response.body)
          assert_equal false, json['success']
          assert_includes json['message'], '栽培スケジュールが含まれています'
        end
        
        test 'remove_field returns error when only one field remains' do
          # cultivation1を削除して、field1を空にする
          @cultivation1.destroy
          
          # field2を先に削除して、field1だけを残す
          @field2.destroy
          @cultivation_plan.reload
          
          field_id = "field_#{@field1.id}"
          
          delete remove_field_api_v1_public_plans_cultivation_plan_path(id: @cultivation_plan.id, field_id: field_id, locale: nil),
                 as: :json
          
          assert_response :bad_request
          json = JSON.parse(response.body)
          assert_equal false, json['success']
          assert_includes json['message'], '最後の圃場は削除できません'
        end
        
        test 'remove_field returns error for non-existent field' do
          delete remove_field_api_v1_public_plans_cultivation_plan_path(id: @cultivation_plan.id, field_id: 'field_99999', locale: nil),
                 as: :json
          
          assert_response :not_found
          json = JSON.parse(response.body)
          assert_equal false, json['success']
          assert_includes json['message'], '圃場が見つかりません'
        end
      end
    end
  end
end

