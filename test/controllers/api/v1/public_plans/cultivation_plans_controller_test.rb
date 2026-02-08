# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    module PublicPlans
      class CultivationPlansControllerTest < ActionDispatch::IntegrationTest
        setup do
          # アノニマスユーザーを作成
          @anonymous_user = User.anonymous_user

          # 参照農場を作成
          @farm = create(:farm, :reference,
            name: '参照農場',
            latitude: 35.6762,
            longitude: 139.6503,
            region: 'jp',
            user: @anonymous_user
          )

          # 天気データロケーションを作成（既に存在する場合は再利用）
          @weather_location = WeatherLocation.find_or_create_by(
            latitude: @farm.latitude,
            longitude: @farm.longitude
          ) do |wl|
            wl.timezone = "Asia/Tokyo"
            wl.elevation = 10.0
          end
          @farm.update(weather_location: @weather_location)

          # Public CultivationPlanを作成
          @cultivation_plan = create(:cultivation_plan,
            farm: @farm,
            user: nil,
            plan_type: 'public',
            status: 'completed'
          )

          # 圃場を作成
          @field = create(:field, farm: @farm, name: 'Test Field')

          # 作物を作成
          @crop = create(:crop, name: 'Test Crop')

          # 作物の成長段階を作成（最低1つ必要）
          create(:crop_stage, :germination, crop: @crop)

          # 栽培計画作物を作成
          @cultivation_plan_crop = create(:cultivation_plan_crop,
            cultivation_plan: @cultivation_plan,
            crop: @crop
          )

          # 栽培計画圃場を作成
          @cultivation_plan_field = create(:cultivation_plan_field,
            cultivation_plan: @cultivation_plan,
            name: 'Test Field',
            area: 1000.0,
            daily_fixed_cost: 500.0
          )

          # 圃場栽培を作成
          @field_cultivation = create(:field_cultivation,
            cultivation_plan: @cultivation_plan,
            cultivation_plan_crop: @cultivation_plan_crop,
            cultivation_plan_field: @cultivation_plan_field,
            start_date: '2026-01-01',
            completion_date: '2026-03-01'
          )
        end
        
        test "find_api_cultivation_plan が正常に動作する（認証不要）" do
          # Concern のメソッドを直接テストするため、コントローラをインスタンス化
          controller = Api::V1::PublicPlans::CultivationPlansController.new
          controller.params = ActionController::Parameters.new(id: @cultivation_plan.id)
          
          plan = controller.send(:find_api_cultivation_plan)
          
          assert_not_nil plan
          assert_equal @cultivation_plan.id, plan.id
          assert_equal 'public', plan.plan_type
        end
        
        test "find_api_cultivation_plan で存在しないIDの場合はRecordNotFoundを発生させる" do
          controller = Api::V1::PublicPlans::CultivationPlansController.new
          controller.params = ActionController::Parameters.new(id: 99999)

          assert_raises(ActiveRecord::RecordNotFound) do
            controller.send(:find_api_cultivation_plan)
          end
        end

        test "data アクションが正常に動作する（認証不要）" do
          # CultivationPlanにplan_typeを設定
          @cultivation_plan.update!(plan_type: 'public')

          # CultivationPlanCropを作成
          plan_crop = CultivationPlanCrop.create!(
            cultivation_plan: @cultivation_plan,
            crop: create(:crop, :reference, region: 'jp'),
            name: 'テスト作物',
            variety: 'テスト品種',
            area_per_unit: 1.0,
            revenue_per_area: 1000.0
          )

          # CultivationPlanFieldを作成
          plan_field = CultivationPlanField.create!(
            cultivation_plan: @cultivation_plan,
            name: 'テスト圃場',
            area: 100.0,
            daily_fixed_cost: 10.0
          )

          # FieldCultivationを作成
          field_cultivation = FieldCultivation.create!(
            cultivation_plan: @cultivation_plan,
            cultivation_plan_field: plan_field,
            cultivation_plan_crop: plan_crop,
            area: 100.0,
            start_date: Date.current,
            completion_date: Date.current + 60.days,
            cultivation_days: 60,
            status: 'completed'
          )

          get "/api/v1/public_plans/cultivation_plans/#{@cultivation_plan.id}/data"

          assert_response :success
          data = JSON.parse(response.body)
          assert data['success']
          assert_equal @cultivation_plan.id, data['data']['id']
          assert_equal 'public', data['data']['plan_type']
          assert data['data']['fields'].is_a?(Array)
          assert data['data']['crops'].is_a?(Array)
          assert data['data']['cultivations'].is_a?(Array)
        end

        test "data action exposes reference crops scoped to farm region" do
          reference_crop = create(:crop, :reference, region: 'jp', name: 'Reference Crop', variety: 'Region Var', area_per_unit: 1.2)
          create(:crop, :reference, region: 'us')

          get "/api/v1/public_plans/cultivation_plans/#{@cultivation_plan.id}/data"

          assert_response :success

          json = JSON.parse(response.body)
          available_crops = json['data']['available_crops']
          assert available_crops.is_a?(Array)
          assert_equal 1, available_crops.size
          crop_json = available_crops.first
          assert_equal reference_crop.id, crop_json['id']
          assert_equal reference_crop.name, crop_json['name']
          assert_equal reference_crop.variety, crop_json['variety']
          assert_equal reference_crop.area_per_unit, crop_json['area_per_unit']
        end

        test "data アクションで存在しないIDの場合は404を返す" do
          get "/api/v1/public_plans/cultivation_plans/99999/data"

          assert_response :not_found
          data = JSON.parse(response.body)
          assert_not data['success']
          assert_includes data['message'], '見つかりません'
        end

        test "adjust endpoint works with proper crop stages" do
          # 作物に成長段階がある場合、adjust APIが成功するはず
          # cultivation_id: 1, from_field: 'Test Field', to_field: 'Test Field', new_start_date: '2026-04-12', daysFromStart: 101

          # WeatherPredictionService をスタブして天気データ不足によるエラーを防ぐ
          weather_double = Object.new
          weather_double.define_singleton_method(:get_existing_prediction) do |**_|
            { data: { 'data' => [{ 'time' => '2026-01-01', 'temperature_2m_mean' => 5.0 }] } }
          end
          weather_double.define_singleton_method(:predict_for_cultivation_plan) do |*|
            { data: { 'data' => [{ 'time' => '2026-01-01', 'temperature_2m_mean' => 5.0 }] } }
          end

          WeatherPredictionService.stub(:new, weather_double) do
            # AGRR AdjustGateway をスタブして成功結果を返すようにする
            adjust_double = Object.new
            # Capture IDs into locals so the singleton method can close over them
            field_id = @cultivation_plan_field.id
            crop_id = @crop.id.to_s
            crop_name = @crop.name
            variety = @cultivation_plan_crop.variety

            allocation = {
              'allocation_id' => nil,
              'crop_id' => crop_id,
              'crop_name' => crop_name,
              'variety' => variety,
              'area_used' => 10.0,
              'start_date' => '2026-04-12',
              'completion_date' => '2026-06-01',
              'growth_days' => 51,
              'accumulated_gdd' => 150.0,
              'total_cost' => 100.0,
              'expected_revenue' => 200.0,
              'profit' => 100.0
            }

            # Define singleton method to return a realistic result (uses captured locals)
            adjust_double.define_singleton_method(:adjust) do |**_|
              {
                field_schedules: [
                  {
                    'field_id' => field_id,
                    'allocations' => [allocation]
                  }
                ],
                total_profit: 100.0,
                total_revenue: 200.0,
                total_cost: 100.0,
                summary: {},
                optimization_time: 0.1,
                algorithm_used: 'test',
                is_optimal: true
              }
            end

            Agrr::AdjustGateway.stub(:new, adjust_double) do
              post "/api/v1/public_plans/cultivation_plans/#{@cultivation_plan.id}/adjust",
                   params: {
                     moves: [
                       {
                         allocation_id: @field_cultivation.id,
                         action: 'move',
                         to_field_id: @cultivation_plan_field.id,
                         to_start_date: '2026-04-12'
                       }
                     ]
                   },
                   headers: { "Accept" => "application/json" }

              # GREEN: 作物に成長段階があれば成功するはず
              assert_response :success, "Expected success but got #{response.status}. Response: #{response.body}"

              json = JSON.parse(response.body)
              assert json['success'], "Response should be successful: #{json.inspect}"
            end
          end
        end

      test "adjust should work" do
        skip "Adjust API test - Action Cable testing requires integration setup"
      end
    end
  end
end
end
