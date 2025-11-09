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
      target_end_date: cultivation_plan.planning_end_date,
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
end


