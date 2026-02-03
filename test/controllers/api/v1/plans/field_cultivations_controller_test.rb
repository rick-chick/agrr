# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    module Plans
      class FieldCultivationsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @user = create(:user)
          @session = Session.create_for_user(@user)
          cookies[:session_id] = @session.session_id
          
          # WeatherLocationを作成
          @weather_location = WeatherLocation.create!(
            latitude: 35.6762,
            longitude: 139.6503,
            timezone: 'Asia/Tokyo',
            elevation: 0.0
          )
          
          # Farmを作成
          @farm = create(:farm,
            user: @user,
            latitude: 35.6762,
            longitude: 139.6503,
            region: 'jp'
          )
          @farm.update!(weather_location: @weather_location)
          
          # Cropを作成
          @crop = create(:crop,
            user: @user,
            name: 'テスト作物',
            variety: 'テスト品種',
            is_reference: false
          )
          
          # CropStageを作成
          @crop_stage = create(:crop_stage,
            crop: @crop,
            name: '発芽期',
            order: 1
          )
          
          # TemperatureRequirementを作成
          create(:temperature_requirement,
            crop_stage: @crop_stage,
            base_temperature: 10.0,
            optimal_min: 15.0,
            optimal_max: 25.0,
            low_stress_threshold: 5.0,
            high_stress_threshold: 30.0
          )
          
          # ThermalRequirementを作成
          create(:thermal_requirement,
            crop_stage: @crop_stage,
            required_gdd: 100.0
          )
          
          # CultivationPlanを作成
          @cultivation_plan = create(:cultivation_plan,
            farm: @farm,
            user: @user,
            plan_type: 'private',
            plan_year: Date.current.year,
            status: 'completed',
            planning_start_date: Date.current,
            planning_end_date: Date.current.end_of_year
          )
          
          # CultivationPlanCropを作成
          @plan_crop = CultivationPlanCrop.create!(
            cultivation_plan: @cultivation_plan,
            crop_id: @crop.id,
            name: @crop.name,
            variety: @crop.variety,
            area_per_unit: @crop.area_per_unit,
            revenue_per_area: @crop.revenue_per_area
          )
          
          # CultivationPlanFieldを作成
          @plan_field = CultivationPlanField.create!(
            cultivation_plan: @cultivation_plan,
            name: '圃場1',
            area: 100.0,
            daily_fixed_cost: 10.0
          )
          
          # FieldCultivationを作成
          @field_cultivation = ::FieldCultivation.create!(
            cultivation_plan: @cultivation_plan,
            cultivation_plan_field: @plan_field,
            cultivation_plan_crop: @plan_crop,
            area: 100.0,
            start_date: Date.current,
            completion_date: Date.current + 60.days,
            cultivation_days: 60,
            status: 'completed'
          )
        end
        
        test "climate_data delegates to interactor success response" do
          success_dto = build_field_climate_success_dto
          with_field_climate_interactor_stub(->(output_port, _) { output_port.present(success_dto) }) do
            get "/api/v1/plans/field_cultivations/#{@field_cultivation.id}/climate_data"
            
            assert_response :success
            data = JSON.parse(response.body)
            assert data['success']
            assert_equal @field_cultivation.id, data['field_cultivation']['id']
          end
        end
        
        test "climate_data delegates to interactor error response" do
          error_dto = Domain::Shared::Dtos::ErrorDto.new('gateway failure')
          with_field_climate_interactor_stub(->(output_port, _) { output_port.on_error(error_dto) }) do
            get "/api/v1/plans/field_cultivations/#{@field_cultivation.id}/climate_data"
            
            assert_response :internal_server_error
            data = JSON.parse(response.body)
            refute data['success']
            assert_equal 'gateway failure', data['message']
          end
        end
        
        test "気象データがある場合、正常にclimate_dataを返す" do
          # 予測データを作成
          predicted_data = {
            'latitude' => @farm.latitude,
            'longitude' => @farm.longitude,
            'timezone' => 'Asia/Tokyo',
            'data' => [
              {
                'time' => @field_cultivation.start_date.to_s,
                'temperature_2m_max' => 20.0,
                'temperature_2m_min' => 10.0,
                'temperature_2m_mean' => 15.0,
                'precipitation_sum' => 0.0
              },
              {
                'time' => (@field_cultivation.start_date + 1.day).to_s,
                'temperature_2m_max' => 22.0,
                'temperature_2m_min' => 12.0,
                'temperature_2m_mean' => 17.0,
                'precipitation_sum' => 0.0
              }
            ],
            'prediction_start_date' => Date.current.to_s,
            'prediction_end_date' => @field_cultivation.completion_date.to_s
          }
          
          @cultivation_plan.update!(predicted_weather_data: predicted_data)
          
          # テスト環境では自動的にモックデータが使われる
          get "/api/v1/plans/field_cultivations/#{@field_cultivation.id}/climate_data"
          
          assert_response :success
          data = JSON.parse(response.body)
          assert data['success']
          assert_equal @field_cultivation.id, data['field_cultivation']['id']
          assert data['gdd_data'].is_a?(Array)
          assert data['weather_data'].is_a?(Array)
        end
        
        test "予測データがない場合、自動生成を試みて正常にレスポンスを返す" do
          @cultivation_plan.update!(predicted_weather_data: nil)
          
          # WeatherPredictionServiceをモック
          mock_service = Minitest::Mock.new
          mock_prediction = {
            data: {
              'latitude' => @farm.latitude,
              'longitude' => @farm.longitude,
              'timezone' => 'Asia/Tokyo',
              'data' => [
                {
                  'time' => @field_cultivation.start_date.to_s,
                  'temperature_2m_max' => 20.0,
                  'temperature_2m_min' => 10.0,
                  'temperature_2m_mean' => 15.0,
                  'precipitation_sum' => 0.0
                }
              ]
            }
          }
          mock_service.expect :predict_for_cultivation_plan, mock_prediction, [@cultivation_plan]
          
          WeatherPredictionService.stub :new, mock_service do
            get "/api/v1/plans/field_cultivations/#{@field_cultivation.id}/climate_data"
            
            assert_response :success
            data = JSON.parse(response.body)
            assert data['success']
            assert_equal @field_cultivation.id, data['field_cultivation']['id']
          end
        end
        
        test "予測データが空の場合、自動生成を試みて正常にレスポンスを返す" do
          @cultivation_plan.update!(predicted_weather_data: {})
          
          # WeatherPredictionServiceをモック
          mock_service = Minitest::Mock.new
          mock_prediction = {
            data: {
              'latitude' => @farm.latitude,
              'longitude' => @farm.longitude,
              'timezone' => 'Asia/Tokyo',
              'data' => [
                {
                  'time' => @field_cultivation.start_date.to_s,
                  'temperature_2m_max' => 20.0,
                  'temperature_2m_min' => 10.0,
                  'temperature_2m_mean' => 15.0,
                  'precipitation_sum' => 0.0
                }
              ]
            }
          }
          mock_service.expect :predict_for_cultivation_plan, mock_prediction, [@cultivation_plan]
          
          WeatherPredictionService.stub :new, mock_service do
            get "/api/v1/plans/field_cultivations/#{@field_cultivation.id}/climate_data"
            
            assert_response :success
            data = JSON.parse(response.body)
            assert data['success']
          end
        end
        
        test "栽培期間が設定されていない場合、400エラーを返す" do
          @field_cultivation.update!(start_date: nil, completion_date: nil)
          
          # 予測データは設定済み
          predicted_data = {
            'latitude' => @farm.latitude,
            'longitude' => @farm.longitude,
            'timezone' => 'Asia/Tokyo',
            'data' => []
          }
          @cultivation_plan.update!(predicted_weather_data: predicted_data)
          
          get "/api/v1/plans/field_cultivations/#{@field_cultivation.id}/climate_data"
          
          assert_response :bad_request
          data = JSON.parse(response.body)
          assert_not data['success']
        end
        
        test "作物が見つからない場合、404エラーを返す" do
          # 別のユーザーの作物IDを設定
          other_user = create(:user)
          other_crop = create(:crop, user: other_user, is_reference: false)
          @plan_crop.update!(crop_id: other_crop.id)
          
          predicted_data = {
            'latitude' => @farm.latitude,
            'longitude' => @farm.longitude,
            'timezone' => 'Asia/Tokyo',
            'data' => []
          }
          @cultivation_plan.update!(predicted_weather_data: predicted_data)
          
          get "/api/v1/plans/field_cultivations/#{@field_cultivation.id}/climate_data"
          
          assert_response :not_found
          data = JSON.parse(response.body)
          assert_not data['success']
          # エラーメッセージを確認（「作物」または「Crop」を含む）
          assert_match(/(作物|Crop)/i, data['message'])
        end
        
        test "気象データの形式が不正な場合、500エラーを返す" do
          # 不正な形式の予測データ
          invalid_data = {
            'data' => nil  # dataがnil
          }
          @cultivation_plan.update!(predicted_weather_data: invalid_data)
          
          get "/api/v1/plans/field_cultivations/#{@field_cultivation.id}/climate_data"
          
          assert_response :internal_server_error
          data = JSON.parse(response.body)
          assert_not data['success']
          assert_includes data['message'], '気象データの形式が不正'
        end
        
        test "WeatherLocationがない場合、404エラーを返す" do
          @farm.update!(weather_location: nil)
          
          predicted_data = {
            'latitude' => @farm.latitude,
            'longitude' => @farm.longitude,
            'timezone' => 'Asia/Tokyo',
            'data' => []
          }
          @cultivation_plan.update!(predicted_weather_data: predicted_data)
          
          get "/api/v1/plans/field_cultivations/#{@field_cultivation.id}/climate_data"
          
          assert_response :not_found
          data = JSON.parse(response.body)
          assert_not data['success']
        end
        
        test "他のユーザーの計画にはアクセスできない" do
          other_user = create(:user)
          other_session = Session.create_for_user(other_user)
          cookies[:session_id] = other_session.session_id
          
          predicted_data = {
            'latitude' => @farm.latitude,
            'longitude' => @farm.longitude,
            'timezone' => 'Asia/Tokyo',
            'data' => []
          }
          @cultivation_plan.update!(predicted_weather_data: predicted_data)
          
          get "/api/v1/plans/field_cultivations/#{@field_cultivation.id}/climate_data"
          
          # find_field_cultivationでRecordNotFoundが発生するため、500エラーまたは404エラーが返る
          assert_includes [404, 500], response.status
          data = JSON.parse(response.body)
          assert_not data['success']
        end
        
        test "show アクションが正常に動作する" do
          get "/api/v1/plans/field_cultivations/#{@field_cultivation.id}"
          
          assert_response :success
          data = JSON.parse(response.body)
          assert_equal @field_cultivation.id, data['id']
          assert_equal @field_cultivation.field_display_name, data['field_name']
          assert_equal @field_cultivation.crop_display_name, data['crop_name']
          assert_equal @field_cultivation.area, data['area']
        end
        
        test "show アクションで他のユーザーの計画にはアクセスできない" do
          other_user = create(:user)
          other_session = Session.create_for_user(other_user)
          cookies[:session_id] = other_session.session_id
          
          get "/api/v1/plans/field_cultivations/#{@field_cultivation.id}"
          
          # find_field_cultivationでRecordNotFoundが発生するため、500エラーまたは404エラーが返る
          assert_includes [404, 500], response.status
        end
        
        test "update アクションが正常に動作する" do
          new_start_date = Date.current + 10.days
          new_completion_date = Date.current + 70.days
          
          patch "/api/v1/plans/field_cultivations/#{@field_cultivation.id}",
                params: {
                  field_cultivation: {
                    start_date: new_start_date,
                    completion_date: new_completion_date
                  }
                }
          
          assert_response :success
          data = JSON.parse(response.body)
          assert data['success']
          assert_equal new_start_date.to_s, data['field_cultivation']['start_date']
          assert_equal new_completion_date.to_s, data['field_cultivation']['completion_date']
          
          @field_cultivation.reload
          assert_equal new_start_date, @field_cultivation.start_date
          assert_equal new_completion_date, @field_cultivation.completion_date
        end
        
        test "update アクションで他のユーザーの計画にはアクセスできない" do
          other_user = create(:user)
          other_session = Session.create_for_user(other_user)
          cookies[:session_id] = other_session.session_id
          
          patch "/api/v1/plans/field_cultivations/#{@field_cultivation.id}",
                params: {
                  field_cultivation: {
                    start_date: Date.current + 10.days,
                    completion_date: Date.current + 70.days
                  }
                }
          
          # find_field_cultivationでRecordNotFoundが発生するため、500エラーまたは404エラーが返る
          assert_includes [404, 500], response.status
        end
        
        private
        
        def with_field_climate_interactor_stub(handler)
          stub_class = Class.new do
            define_method(:initialize) do |output_port:, gateway:|
              @output_port = output_port
            end

            define_method(:call) do |input_dto|
              handler.call(@output_port, input_dto)
            end
          end

          FieldCultivationClimateDataInteractor.stub :new, ->(**kwargs) { stub_class.new(**kwargs) } do
            yield
          end
        end

        def build_field_climate_success_dto
          success_struct = Struct.new(
            :field_cultivation, :farm, :crop_requirements,
            :weather_data, :gdd_data, :stages,
            :progress_result, :debug_info
          )

          success_struct.new(
            {
              id: @field_cultivation.id,
              field_name: @field_cultivation.field_display_name,
              crop_name: @field_cultivation.crop_display_name,
              start_date: @field_cultivation.start_date,
              completion_date: @field_cultivation.completion_date
            },
            {
              id: @farm.id,
              name: @farm.display_name,
              latitude: @farm.latitude,
              longitude: @farm.longitude
            },
            { base_temperature: 10.0 },
            [],
            [],
            [],
            {},
            {}
          )
        end
      end
    end
  end
end

