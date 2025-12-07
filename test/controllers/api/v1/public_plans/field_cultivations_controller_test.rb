# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    module PublicPlans
      class FieldCultivationsControllerTest < ActionDispatch::IntegrationTest
        setup do
          # アノニマスユーザーを作成
          @anonymous_user = User.anonymous_user
          
          # WeatherLocationを作成
          @weather_location = WeatherLocation.create!(
            latitude: 35.6762,
            longitude: 139.6503,
            timezone: 'Asia/Tokyo',
            elevation: 0.0
          )
          
          # 参照農場を作成
          @farm = create(:farm, :reference,
            name: '参照農場',
            latitude: 35.6762,
            longitude: 139.6503,
            region: 'jp',
            user: @anonymous_user,
            weather_location: @weather_location
          )
          
          # 参照作物を作成
          @crop = create(:crop, :reference,
            name: '参照作物',
            variety: 'テスト品種',
            region: 'jp',
            user: nil
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
          
          # Public CultivationPlanを作成
          @cultivation_plan = create(:cultivation_plan,
            farm: @farm,
            user: nil,
            plan_type: 'public',
            status: 'completed'
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
          @field_cultivation = FieldCultivation.create!(
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
        
        test "show アクションが正常に動作する（認証不要）" do
          get "/api/v1/public_plans/field_cultivations/#{@field_cultivation.id}"
          
          assert_response :success
          data = JSON.parse(response.body)
          assert_equal @field_cultivation.id, data['id']
          assert_equal @field_cultivation.field_display_name, data['field_name']
          assert_equal @field_cultivation.crop_display_name, data['crop_name']
          assert_equal @field_cultivation.area, data['area']
        end
        
        test "show アクションで存在しないIDの場合は404を返す" do
          get "/api/v1/public_plans/field_cultivations/99999"
          
          assert_response :not_found
        end

        test "climate_data returns localized message when no predicted weather data" do
          @cultivation_plan.update!(predicted_weather_data: nil)

          get "/api/v1/public_plans/field_cultivations/#{@field_cultivation.id}/climate_data"
          assert_response :not_found

          data = JSON.parse(response.body)
          assert_equal I18n.t('api.errors.no_weather_data'), data['message']
        end
        
        test "climate_data アクションが正常に動作する（認証不要）" do
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
          get "/api/v1/public_plans/field_cultivations/#{@field_cultivation.id}/climate_data"
          
          assert_response :success
          data = JSON.parse(response.body)
          assert data['success']
          assert_equal @field_cultivation.id, data['field_cultivation']['id']
          assert data['gdd_data'].is_a?(Array)
          assert data['weather_data'].is_a?(Array)
        end
        
        test "update アクションが正常に動作する（認証不要）" do
          new_start_date = Date.current + 10.days
          new_completion_date = Date.current + 70.days
          
          patch "/api/v1/public_plans/field_cultivations/#{@field_cultivation.id}",
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
        
        test "update アクションで存在しないIDの場合は404を返す" do
          patch "/api/v1/public_plans/field_cultivations/99999",
                params: {
                  field_cultivation: {
                    start_date: Date.current + 10.days,
                    completion_date: Date.current + 70.days
                  }
                }
          
          assert_response :not_found
        end
      end
    end
  end
end
