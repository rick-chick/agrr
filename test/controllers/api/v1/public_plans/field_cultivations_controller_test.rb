# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module PublicPlans
      class FieldCultivationsControllerTest < ActionDispatch::IntegrationTest
        def setup
          # 参照農場を作成
          @farm = Farm.create!(
            name: "北海道・札幌",
            latitude: 43.0642,
            longitude: 141.3469,
            is_reference: true
          )
          
          # 天気ロケーションを作成
          @weather_location = WeatherLocation.create!(
            latitude: @farm.latitude,
            longitude: @farm.longitude,
            timezone: "Asia/Tokyo",
            elevation: 10.0
          )
          
          # 天気データを作成
          create_weather_data
          
          # 作付け計画を作成
          @cultivation_plan = create_completed_cultivation_plan
          @field_cultivation = @cultivation_plan.field_cultivations.first
        end

        # ========================================
        # show アクション
        # ========================================
        
        test "should return field cultivation details" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          assert_equal @field_cultivation.id, json['id']
          assert_equal @field_cultivation.field_display_name, json['field_name']
          assert_equal @field_cultivation.crop_display_name, json['crop_name']
        end
        
        test "should return basic information" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          assert_not_nil json['area']
          assert_not_nil json['start_date']
          assert_not_nil json['completion_date']
          assert_not_nil json['cultivation_days']
          assert_not_nil json['estimated_cost']
        end
        
        test "should return gdd information" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          assert_not_nil json['gdd']
          assert json['gdd'] > 0
        end
        
        test "should return stages data" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          assert json['stages'].is_a?(Array)
          assert json['stages'].length > 0
          
          stage = json['stages'].first
          assert_not_nil stage['name']
          assert_not_nil stage['start_date']
          assert_not_nil stage['end_date']
          assert_not_nil stage['days']
          assert_not_nil stage['gdd_required']
          assert_not_nil stage['gdd_actual']
        end
        
        test "stages should have required fields" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          stage = json['stages'].first
          
          assert stage.key?('name')
          assert stage.key?('start_date')
          assert stage.key?('end_date')
          assert stage.key?('days')
          assert stage.key?('gdd_required')
          assert stage.key?('gdd_actual')
          assert stage.key?('gdd_achieved')
          assert stage.key?('avg_temp')
          assert stage.key?('optimal_temp_min')
          assert stage.key?('optimal_temp_max')
          assert stage.key?('risks')
        end
        
        test "should return weather data for cultivation period" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          assert json['weather_data'].is_a?(Array)
          assert json['weather_data'].length > 0
          
          weather = json['weather_data'].first
          assert_not_nil weather['date']
          assert_not_nil weather['temperature_max']
          assert_not_nil weather['temperature_min']
          assert_not_nil weather['temperature_mean']
        end
        
        test "weather data should be within cultivation period" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          weather_dates = json['weather_data'].map { |w| Date.parse(w['date']) }
          
          assert weather_dates.all? { |d| d >= @field_cultivation.start_date }
          assert weather_dates.all? { |d| d <= @field_cultivation.completion_date }
        end
        
        test "should return temperature statistics" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          stats = json['temperature_stats']
          
          assert_not_nil stats
          assert_not_nil stats['total_days']
          assert_not_nil stats['optimal_days']
          assert_not_nil stats['optimal_percentage']
          assert_not_nil stats['high_temp_days']
          assert_not_nil stats['low_temp_days']
        end
        
        test "temperature stats should be valid" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          stats = json['temperature_stats']
          
          assert stats['total_days'] > 0
          assert stats['optimal_days'] >= 0
          assert stats['optimal_days'] <= stats['total_days']
          assert stats['optimal_percentage'] >= 0
          assert stats['optimal_percentage'] <= 100
          assert stats['high_temp_days'] >= 0
          assert stats['low_temp_days'] >= 0
        end
        
        test "should return gdd info" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          gdd_info = json['gdd_info']
          
          assert_not_nil gdd_info
          assert_not_nil gdd_info['target']
          assert_not_nil gdd_info['actual']
          assert_not_nil gdd_info['percentage']
          assert_not_nil gdd_info['achievement_date']
        end
        
        test "gdd info should be valid" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          gdd_info = json['gdd_info']
          
          assert gdd_info['target'] > 0
          assert gdd_info['actual'] > 0
          assert gdd_info['percentage'].is_a?(Numeric)
        end
        
        test "should return gdd chart data" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          gdd_data = json['gdd_data']
          
          assert gdd_data.is_a?(Array)
          assert gdd_data.length > 0
          
          point = gdd_data.first
          assert_not_nil point['date']
          assert_not_nil point['accumulated_gdd']
          assert_not_nil point['target_gdd']
        end
        
        test "gdd chart data should be cumulative" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          gdd_data = json['gdd_data']
          
          # 積算温度は増加するはず
          accumulated_values = gdd_data.map { |d| d['accumulated_gdd'] }
          assert_equal accumulated_values, accumulated_values.sort
        end
        
        test "should return optimal temperature range" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          temp_range = json['optimal_temperature_range']
          
          assert_not_nil temp_range
          assert_not_nil temp_range['min']
          assert_not_nil temp_range['max']
          assert temp_range['max'] > temp_range['min']
        end
        
        test "should return 404 for non-existent field cultivation" do
          get api_v1_public_plans_field_cultivation_path(id: 999999), as: :json
          
          assert_response :not_found
          json = JSON.parse(response.body)
          assert_not_nil json['error']
        end
        
        test "should return empty arrays when no weather data available" do
          # 天気データがない場合
          @weather_location.weather_data.destroy_all
          
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          assert_equal [], json['weather_data']
          assert_nil json['temperature_stats']
          assert_equal [], json['gdd_data']
        end
        
        test "should handle field cultivation without optimization result" do
          # optimization_result が nil の場合
          @field_cultivation.update!(optimization_result: nil)
          
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          assert_equal [], json['stages']
          assert_nil json['gdd']
        end
        
        test "should handle field cultivation without dates" do
          # start_date と completion_date が nil の場合
          @field_cultivation.update!(start_date: nil, completion_date: nil)
          
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          assert_nil json['start_date']
          assert_nil json['completion_date']
          assert_equal [], json['weather_data']
        end
        
        # ========================================
        # JSON構造のテスト
        # ========================================
        
        test "response should have all required keys" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          required_keys = %w[
            id field_name crop_name area start_date completion_date
            cultivation_days gdd estimated_cost stages weather_data
            temperature_stats gdd_info gdd_data optimal_temperature_range
          ]
          
          required_keys.each do |key|
            assert json.key?(key), "Missing key: #{key}"
          end
        end
        
        test "response should be valid JSON" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          assert_nothing_raised do
            JSON.parse(response.body)
          end
        end
        
        test "response should have correct content type" do
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          assert_equal "application/json; charset=utf-8", response.content_type
        end
        
        # ========================================
        # パフォーマンステスト
        # ========================================
        
        test "should handle large weather data efficiently" do
          # 大量の天気データを作成（2年分）
          (Date.new(2023, 1, 1)..Date.new(2024, 12, 31)).each do |date|
            WeatherDatum.create!(
              weather_location: @weather_location,
              date: date,
              temperature_max: 20.0,
              temperature_min: 10.0,
              temperature_mean: 15.0
            )
          end
          
          get api_v1_public_plans_field_cultivation_path(@field_cultivation), as: :json
          
          assert_response :success
          
          json = JSON.parse(response.body)
          # 栽培期間のデータのみ返されることを確認
          assert json['weather_data'].length <= @field_cultivation.cultivation_days + 1
        end
        
        # ========================================
        # ヘルパーメソッド
        # ========================================
        
        private
        
        def create_weather_data
          # 2024年の天気データを作成
          (Date.new(2024, 1, 1)..Date.new(2024, 12, 31)).each do |date|
            WeatherDatum.create!(
              weather_location: @weather_location,
              date: date,
              temperature_max: 20.0 + rand(-5.0..10.0),
              temperature_min: 10.0 + rand(-5.0..5.0),
              temperature_mean: 15.0 + rand(-5.0..7.0),
              precipitation: rand(0.0..10.0),
              sunshine_hours: rand(0.0..12.0)
            )
          end
        end
        
        def create_completed_cultivation_plan
          plan = CultivationPlan.create!(
            farm: @farm,
            total_area: 100.0,
            status: :completed
          )
          
          field = CultivationPlanField.create!(
            cultivation_plan: plan,
            name: "第1圃場",
            area: 100.0,
            daily_fixed_cost: 1000.0
          )
          
          crop = CultivationPlanCrop.create!(
            cultivation_plan: plan,
            name: "トマト",
            variety: "桃太郎",
            agrr_crop_id: "トマト"
          )
          
          FieldCultivation.create!(
            cultivation_plan: plan,
            cultivation_plan_field: field,
            cultivation_plan_crop: crop,
            area: 100.0,
            start_date: Date.new(2024, 4, 15),
            completion_date: Date.new(2024, 8, 20),
            cultivation_days: 127,
            estimated_cost: 85000.0,
            status: :completed,
            optimization_result: {
              start_date: "2024-04-15",
              completion_date: "2024-08-20",
              days: 127,
              cost: 85000.0,
              gdd: 2456.0,
              raw: {
                target_gdd: 2400.0,
                stages: [
                  {
                    name: "発芽",
                    start_date: "2024-04-15",
                    end_date: "2024-04-30",
                    days: 15,
                    gdd_required: 200,
                    gdd_actual: 205,
                    avg_temp: 16.2,
                    optimal_temp_min: 15,
                    optimal_temp_max: 25,
                    risks: []
                  },
                  {
                    name: "成長",
                    start_date: "2024-05-01",
                    end_date: "2024-06-30",
                    days: 60,
                    gdd_required: 1200,
                    gdd_actual: 1215,
                    avg_temp: 22.5,
                    optimal_temp_min: 18,
                    optimal_temp_max: 28,
                    risks: []
                  },
                  {
                    name: "開花",
                    start_date: "2024-07-01",
                    end_date: "2024-07-20",
                    days: 20,
                    gdd_required: 400,
                    gdd_actual: 410,
                    avg_temp: 25.0,
                    optimal_temp_min: 20,
                    optimal_temp_max: 30,
                    risks: []
                  }
                ]
              }
            }
          )
          
          plan
        end
      end
    end
  end
end


