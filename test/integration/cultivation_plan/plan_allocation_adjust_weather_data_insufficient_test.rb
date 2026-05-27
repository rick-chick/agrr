# frozen_string_literal: true

require "test_helper"

# PlanAllocationAdjustInteractor: 計画期間外修正時の気象予測再利用（AR 統合。HTTP 境界ではない）。
class CultivationPlan::PlanAllocationAdjustWeatherDataInsufficientTest < ActiveSupport::TestCase
  include PlanAllocationAdjustTestSupport

  def setup
      @lat = 35.0 + SecureRandom.random_number * 10
      @lon = 139.0 + SecureRandom.random_number * 10

      @user = create(:user)
      @farm = create(:farm, user: @user, latitude: @lat, longitude: @lon, region: "jp")
      @weather_location = create(:weather_location,
        latitude: @lat,
        longitude: @lon,
        elevation: 50.0,
        timezone: "Asia/Tokyo"
      )
      @farm.update!(weather_location: @weather_location)

      @planning_start_date = Date.new(2024, 1, 1)
      @planning_end_date = Date.new(2024, 12, 31)

      @plan = create(:cultivation_plan,
        farm: @farm,
        user: @user,
        plan_type: "private",
        planning_start_date: @planning_start_date,
        planning_end_date: @planning_end_date,
        status: "completed"
      )

      @field = create(:cultivation_plan_field, cultivation_plan: @plan, name: "Field 1", area: 100.0)
      @crop = create(:crop, :with_stages, user: @user, region: "jp")
      @plan_crop = create(:cultivation_plan_crop, cultivation_plan: @plan, crop: @crop)

      @field_cultivation = create(:field_cultivation,
        cultivation_plan: @plan,
        cultivation_plan_field: @field,
        cultivation_plan_crop: @plan_crop,
        start_date: Date.new(2024, 4, 1),
        completion_date: Date.new(2024, 6, 30),
        area: 50.0,
        estimated_cost: 1000.0,
        optimization_result: {
          revenue: 2000.0,
          profit: 1000.0,
          accumulated_gdd: 500.0
        }
      )

      stub_all_agrr_commands
    end

  test "計画期間外で修正処理を実行する場合、effective_planning_endまで新規予測を実行する" do
      moves = [ {
        allocation_id: @field_cultivation.id,
        to_field_id: @field.id,
        to_start_date: Date.new(2025, 6, 1).to_s,
        to_completion_date: Date.new(2025, 8, 31).to_s
      } ]

      @plan.update!(predicted_weather_data: {
        "data" => generate_prediction_data(Date.new(2024, 1, 1), Date.new(2024, 12, 31)),
        "prediction_start_date" => Date.new(2024, 1, 1).to_s,
        "prediction_end_date" => Date.new(2024, 12, 31).to_s,
        "predicted_at" => Time.current.iso8601,
        "model" => "lightgbm"
      })

      weather_prediction_service = Minitest::Mock.new
      weather_prediction_service.expect(:get_existing_prediction, nil) do |kwargs|
        kwargs[:target_end_date] == Date.new(2026, 12, 31) && kwargs[:cultivation_plan_weather].id == @plan.id
      end

      prediction_result = {
        data: {
          "data" => generate_prediction_data(Date.new(2024, 1, 1), Date.new(2026, 12, 31)),
          "prediction_start_date" => Date.new(2024, 1, 1).to_s,
          "prediction_end_date" => Date.new(2026, 12, 31).to_s
        },
        target_end_date: Date.new(2026, 12, 31),
        prediction_start_date: Date.new(2024, 1, 1).to_s,
        prediction_days: 1095
      }
      weather_prediction_service.expect(:predict_for_cultivation_plan, prediction_result) do |plan_weather:, target_end_date:|
        plan_weather.id == @plan.id && target_end_date == Date.new(2026, 12, 31)
      end

      Domain::WeatherData::Interactors::WeatherPredictionInteractor.stub(:new, weather_prediction_service) do
        result = run_plan_allocation_adjust(plan_id: @plan.id, moves: moves)

        assert result.success?, "修正処理が成功する必要がある。エラー: #{result.message}"
        weather_prediction_service.verify
      end
    end

  test "既存の予測データがeffective_planning_endをカバーしている場合、既存データを再利用する" do
      moves = [ {
        allocation_id: @field_cultivation.id,
        to_field_id: @field.id,
        to_start_date: Date.new(2025, 6, 1).to_s,
        to_completion_date: Date.new(2025, 8, 31).to_s
      } ]

      existing_prediction_data = {
        "data" => generate_prediction_data(Date.new(2024, 1, 1), Date.new(2026, 12, 31)),
        "prediction_start_date" => Date.new(2024, 1, 1).to_s,
        "prediction_end_date" => Date.new(2026, 12, 31).to_s,
        "predicted_at" => Time.current.iso8601,
        "model" => "lightgbm"
      }
      @plan.update!(predicted_weather_data: existing_prediction_data)

      weather_prediction_service = Minitest::Mock.new
      existing_result = {
        data: existing_prediction_data,
        target_end_date: Date.new(2026, 12, 31),
        prediction_start_date: Date.new(2024, 1, 1).to_s,
        prediction_days: 1095
      }
      weather_prediction_service.expect(:get_existing_prediction, existing_result) do |kwargs|
        kwargs[:target_end_date] == Date.new(2026, 12, 31) && kwargs[:cultivation_plan_weather].id == @plan.id
      end

      Domain::WeatherData::Interactors::WeatherPredictionInteractor.stub(:new, weather_prediction_service) do
        result = run_plan_allocation_adjust(plan_id: @plan.id, moves: moves)

        assert result.success?, "修正処理が成功する必要がある。エラー: #{result.message}"
        weather_prediction_service.verify
      end
    end

  test "新規予測を実行した場合、予測データが保存される" do
      moves = [ {
        allocation_id: @field_cultivation.id,
        to_field_id: @field.id,
        to_start_date: Date.new(2025, 6, 1).to_s,
        to_completion_date: Date.new(2025, 8, 31).to_s
      } ]

      @plan.update!(predicted_weather_data: {
        "data" => generate_prediction_data(Date.new(2024, 1, 1), Date.new(2024, 12, 31)),
        "prediction_start_date" => Date.new(2024, 1, 1).to_s,
        "prediction_end_date" => Date.new(2024, 12, 31).to_s,
        "predicted_at" => Time.current.iso8601,
        "model" => "lightgbm"
      })

      weather_prediction_service = Minitest::Mock.new
      weather_prediction_service.expect(:get_existing_prediction, nil) do |kwargs|
        kwargs[:target_end_date] == Date.new(2026, 12, 31) && kwargs[:cultivation_plan_weather].id == @plan.id
      end

      new_prediction_data = {
        "data" => generate_prediction_data(Date.new(2024, 1, 1), Date.new(2026, 12, 31)),
        "prediction_start_date" => Date.new(2024, 1, 1).to_s,
        "prediction_end_date" => Date.new(2026, 12, 31).to_s,
        "predicted_at" => Time.current.iso8601,
        "model" => "lightgbm"
      }
      prediction_result = {
        data: new_prediction_data,
        target_end_date: Date.new(2026, 12, 31),
        prediction_start_date: Date.new(2024, 1, 1).to_s,
        prediction_days: 1095
      }
      weather_prediction_service.expect(:predict_for_cultivation_plan, prediction_result) do |plan_weather:, target_end_date:|
        plan_weather.id == @plan.id && target_end_date == Date.new(2026, 12, 31)
      end

      Domain::WeatherData::Interactors::WeatherPredictionInteractor.stub(:new, weather_prediction_service) do
        result = run_plan_allocation_adjust(plan_id: @plan.id, moves: moves)

        assert result.success?, "修正処理が成功する必要がある。エラー: #{result.message}"

        weather_prediction_service.verify

        @plan.update!(predicted_weather_data: new_prediction_data)
        @plan.reload
        assert_not_nil @plan.predicted_weather_data
        assert_equal Date.new(2026, 12, 31).to_s, @plan.predicted_weather_data["prediction_end_date"]
      end
    end

  test "次回以降、保存された予測データが再利用される" do
      moves1 = [ {
        allocation_id: @field_cultivation.id,
        to_field_id: @field.id,
        to_start_date: Date.new(2025, 6, 1).to_s,
        to_completion_date: Date.new(2025, 8, 31).to_s
      } ]

      @plan.update!(predicted_weather_data: {
        "data" => generate_prediction_data(Date.new(2024, 1, 1), Date.new(2024, 12, 31)),
        "prediction_start_date" => Date.new(2024, 1, 1).to_s,
        "prediction_end_date" => Date.new(2024, 12, 31).to_s,
        "predicted_at" => Time.current.iso8601,
        "model" => "lightgbm"
      })

      weather_prediction_service1 = Minitest::Mock.new
      weather_prediction_service1.expect(:get_existing_prediction, nil) do |kwargs|
        kwargs[:target_end_date] == Date.new(2026, 12, 31) && kwargs[:cultivation_plan_weather].id == @plan.id
      end

      new_prediction_data = {
        "data" => generate_prediction_data(Date.new(2024, 1, 1), Date.new(2026, 12, 31)),
        "prediction_start_date" => Date.new(2024, 1, 1).to_s,
        "prediction_end_date" => Date.new(2026, 12, 31).to_s,
        "predicted_at" => Time.current.iso8601,
        "model" => "lightgbm"
      }
      prediction_result1 = {
        data: new_prediction_data,
        target_end_date: Date.new(2026, 12, 31),
        prediction_start_date: Date.new(2024, 1, 1).to_s,
        prediction_days: 1095
      }
      weather_prediction_service1.expect(:predict_for_cultivation_plan, prediction_result1) do |plan_weather:, target_end_date:|
        plan_weather.id == @plan.id && target_end_date == Date.new(2026, 12, 31)
      end

      Domain::WeatherData::Interactors::WeatherPredictionInteractor.stub(:new, weather_prediction_service1) do
        result1 = run_plan_allocation_adjust(plan_id: @plan.id, moves: moves1)
        assert result1.success?, "1回目の修正処理が成功する必要がある。エラー: #{result1.message}"
        weather_prediction_service1.verify
      end

      moves2 = [ {
        allocation_id: @field_cultivation.id,
        to_field_id: @field.id,
        to_start_date: Date.new(2025, 7, 1).to_s,
        to_completion_date: Date.new(2025, 9, 30).to_s
      } ]

      weather_prediction_service2 = Minitest::Mock.new
      existing_result = {
        data: new_prediction_data,
        target_end_date: Date.new(2026, 12, 31),
        prediction_start_date: Date.new(2024, 1, 1).to_s,
        prediction_days: 1095
      }
      weather_prediction_service2.expect(:get_existing_prediction, existing_result) do |kwargs|
        kwargs[:target_end_date] == Date.new(2026, 12, 31) && kwargs[:cultivation_plan_weather].id == @plan.id
      end

      Domain::WeatherData::Interactors::WeatherPredictionInteractor.stub(:new, weather_prediction_service2) do
        result2 = run_plan_allocation_adjust(plan_id: @plan.id, moves: moves2)

        assert result2.success?, "2回目の修正処理が成功する必要がある。エラー: #{result2.message}"
        weather_prediction_service2.verify
      end
    end

  private

  def generate_prediction_data(start_date, end_date)
    (start_date..end_date).map do |date|
      {
        "time" => date.to_s,
        "temperature_2m_max" => 20.0 + (date.yday % 10),
        "temperature_2m_min" => 10.0 + (date.yday % 8),
        "temperature_2m_mean" => 15.0 + (date.yday % 9),
        "precipitation_sum" => date.day.even? ? 0.0 : 5.0,
        "sunshine_duration" => (6.0 + (date.yday % 6)) * 3600.0,
        "wind_speed_10m_max" => 3.0 + (date.yday % 5),
        "weather_code" => date.day.even? ? 0 : 61
      }
    end
  end
end
