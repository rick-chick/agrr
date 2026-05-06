# frozen_string_literal: true

require "test_helper"

module Domain
  module WeatherData
    module Services
      class AdjustHistoricalPredictionMergerTest < ActiveSupport::TestCase
        test "build_historical_agrr_series skips rows missing temperatures and formats AGRR points" do
          rows = [
            {
              date: Date.new(2025, 6, 1),
              temperature_max: 30.0, temperature_min: 10.0, temperature_mean: nil,
              precipitation: 1.5, sunshine_hours: 2.0, wind_speed: 3.0, weather_code: 1
            },
            { date: Date.new(2025, 6, 2), temperature_max: nil, temperature_min: 10.0 },
            { "date" => Date.new(2025, 6, 3), "temperature_max" => 20.0, "temperature_min" => 12.0, "temperature_mean" => 18.0 }
          ]

          series = AdjustHistoricalPredictionMerger.build_historical_agrr_series(
            latitude: 35.5,
            longitude: 140.1,
            elevation: 10.0,
            timezone: "Asia/Tokyo",
            rows: rows
          )

          assert_equal 35.5, series["latitude"]
          assert_equal 140.1, series["longitude"]
          assert_equal 10.0, series["elevation"]
          assert_equal "Asia/Tokyo", series["timezone"]
          assert_equal 2, series["data"].size

          p0 = series["data"].first
          assert_equal "2025-06-01", p0["time"]
          assert_in_delta 30.0, p0["temperature_2m_max"]
          assert_in_delta 10.0, p0["temperature_2m_min"]
          assert_in_delta 20.0, p0["temperature_2m_mean"]
          assert_in_delta 1.5, p0["precipitation_sum"]
          assert_in_delta 7200.0, p0["sunshine_duration"]
          assert_in_delta 3.0, p0["wind_speed_10m_max"]
          assert_equal 1, p0["weather_code"]

          p1 = series["data"].last
          assert_equal "2025-06-03", p1["time"]
          assert_in_delta 18.0, p1["temperature_2m_mean"]
        end

        test "merge_historical_series_with_prediction concatenates data arrays" do
          historical_series = {
            "latitude" => 1.0,
            "longitude" => 2.0,
            "elevation" => 3.0,
            "timezone" => "UTC",
            "data" => [ { "time" => "2025-01-01" } ]
          }
          prediction_data = { "data" => [ { "time" => "2025-02-01" } ] }

          merged = AdjustHistoricalPredictionMerger.merge_historical_series_with_prediction(
            historical_series,
            prediction_data
          )

          assert_equal 1.0, merged["latitude"]
          assert_equal 2, merged["data"].size
          assert_equal "2025-01-01", merged["data"].first["time"]
          assert_equal "2025-02-01", merged["data"].last["time"]
        end

        test "merge_historical_series_with_prediction treats missing prediction data as empty" do
          historical_series = {
            "latitude" => 1.0,
            "longitude" => 2.0,
            "elevation" => 3.0,
            "timezone" => "UTC",
            "data" => [ { "time" => "2025-01-01" } ]
          }

          merged = AdjustHistoricalPredictionMerger.merge_historical_series_with_prediction(
            historical_series,
            {}
          )

          assert_equal 1, merged["data"].size
        end
      end
    end
  end
end
