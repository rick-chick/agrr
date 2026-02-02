# frozen_string_literal: true

require "test_helper"

class WeatherPredictionServiceTest < ActiveSupport::TestCase
  setup do
    @weather_location = create(:weather_location)
    @user = create(:user)
    @farm = create(:farm, user: @user, weather_location: @weather_location)
  end

  test "initialize requires weather_location" do
    error = assert_raises(ArgumentError) do
      WeatherPredictionService.new(weather_location: nil)
    end
    assert_includes error.message, "weather_location"
  end

  test "get_existing_prediction returns cached location prediction when available" do
    prediction_payload = {
      "data" => [
        { "time" => "2025-01-01", "temperature_2m_max" => 15.0, "temperature_2m_min" => 5.0, "temperature_2m_mean" => 10.0, "precipitation_sum" => 0.0 }
      ],
      "prediction_start_date" => "2025-01-01",
      "prediction_end_date" => "2025-12-31",
      "generated_at" => Time.current.iso8601,
      "predicted_at" => Time.current.iso8601,
      "target_end_date" => "2025-12-31",
      "model" => "lightgbm"
    }
    @weather_location.update!(predicted_weather_data: prediction_payload)

    service = WeatherPredictionService.new(weather_location: @weather_location)
    result = service.get_existing_prediction(target_end_date: Date.new(2025, 12, 31))

    assert_not_nil result
    assert_equal prediction_payload, result[:data]
    assert_equal "2025-01-01", result[:prediction_start_date]
  end

  test "predict_for_cultivation_plan persists prediction on weather_location" do
    cultivation_plan = create(:cultivation_plan, farm: @farm, user: @user, planning_end_date: Date.new(2025, 12, 31))
    # 作付計画を作成してcalculated_planning_end_dateが正しい値を返すようにする
    plan_field = create(:cultivation_plan_field, cultivation_plan: cultivation_plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: cultivation_plan)
    create(
      :field_cultivation,
      cultivation_plan: cultivation_plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(2025, 4, 1),
      completion_date: Date.new(2025, 10, 31)
    )

    fake_weather_info = {
      data: {
        "latitude" => @weather_location.latitude.to_f,
        "longitude" => @weather_location.longitude.to_f,
        "elevation" => @weather_location.elevation.to_f,
        "timezone" => @weather_location.timezone,
        "data" => [
          { "time" => "2025-01-01", "temperature_2m_max" => 20.0, "temperature_2m_min" => 10.0, "temperature_2m_mean" => 15.0, "precipitation_sum" => 0.0 }
        ]
      },
      prediction_start_date: "2025-01-01",
      target_end_date: cultivation_plan.prediction_target_end_date,
      prediction_days: 365
    }

    service = WeatherPredictionService.new(weather_location: @weather_location, farm: @farm)

    service.stub(:prepare_weather_data, fake_weather_info) do
      service.predict_for_cultivation_plan(cultivation_plan)
    end

    @weather_location.reload
    cultivar_prediction = cultivation_plan.reload.predicted_weather_data

    assert_equal @weather_location.predicted_weather_data, cultivar_prediction
    assert_equal "lightgbm", @weather_location.predicted_weather_data["model"]
    assert_equal "2025-01-01", @weather_location.predicted_weather_data["prediction_start_date"]
    assert_equal "2025-12-31", @weather_location.predicted_weather_data["target_end_date"]
  end

  test "predict_for_cultivation_plan uses prediction data when current year data is missing" do
    # 作付計画を作成
    cultivation_plan = create(:cultivation_plan, farm: @farm, user: @user, planning_end_date: Date.new(2025, 12, 31))
    plan_field = create(:cultivation_plan_field, cultivation_plan: cultivation_plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: cultivation_plan)
    create(
      :field_cultivation,
      cultivation_plan: cultivation_plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(2025, 4, 1),
      completion_date: Date.new(2025, 10, 31)
    )

    # 現在の年のデータを削除して空の状態を作る
    current_year_start = Date.new(Date.current.year, 1, 1)
    current_year_end = Date.current - 2.days

    # 現在の年のデータを削除
    @weather_location.weather_data.where(date: current_year_start..current_year_end).delete_all

    # 現在の年のデータが存在しないことを確認
    current_year_data = @weather_location.weather_data.where(date: current_year_start..current_year_end)
    assert_empty current_year_data, "Current year data should be empty for this test"

    service = WeatherPredictionService.new(weather_location: @weather_location, farm: @farm)

    # トレーニングデータをモックして十分なデータがあるようにする
    # テスト用トレーニングデータは本番同等の大量作成は重いため縮小して疑似データを使用
    fake_training_data = (1..100).map { |i| build_stubbed(:weather_datum, weather_location: @weather_location, date: Date.current - 100 + i.days, temperature_max: 20.0) }
    service.stub(:get_training_data, fake_training_data) do
      # 予測データをモック
      fake_prediction = {
        'latitude' => @weather_location.latitude.to_f,
        'longitude' => @weather_location.longitude.to_f,
        'elevation' => (@weather_location.elevation || 0.0).to_f,
        'timezone' => @weather_location.timezone,
        'data' => [
          { 'time' => '2026-01-30', 'temperature_2m_max' => 20.0, 'temperature_2m_min' => 10.0, 'temperature_2m_mean' => 15.0, 'precipitation_sum' => 0.0 }
        ]
      }
      service.stub(:get_prediction_data, fake_prediction) do
        # predict_for_cultivation_plan が現在の年のデータがなくても正常に動作することを確認
        result = service.predict_for_cultivation_plan(cultivation_plan)

        assert_not_nil result
        assert_not_nil result[:data]
        # 現在の年のデータがない場合でも予測データが使用される
        assert result[:data]['data'].is_a?(Array)
        assert_not_empty result[:data]['data'], "Prediction data should be used when current year data is missing"
      end
    end
  end
end



