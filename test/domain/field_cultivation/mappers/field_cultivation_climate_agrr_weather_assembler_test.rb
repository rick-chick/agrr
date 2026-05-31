# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Mappers
      class FieldCultivationClimateAgrrWeatherAssemblerTest < DomainLibTestCase
        WeatherDatum = Struct.new(
          :date, :temperature_max, :temperature_min, :temperature_mean,
          :precipitation, :sunshine_hours, :wind_speed, :weather_code,
          keyword_init: true
        )

        def weather_location_meta
          {
            latitude: 43.0,
            longitude: 141.0,
            elevation: 0.0,
            timezone: "Asia/Tokyo"
          }
        end

        test "merges observed cultivation-period rows ahead of cached prediction-only tail" do
          cached = {
            "latitude" => 43.0,
            "longitude" => 141.0,
            "timezone" => "Asia/Tokyo",
            "data" => [
              {
                "time" => "2026-05-31",
                "temperature_2m_max" => 27.0,
                "temperature_2m_min" => 16.0,
                "temperature_2m_mean" => 21.5
              },
              {
                "time" => "2026-06-01",
                "temperature_2m_max" => 28.0,
                "temperature_2m_min" => 17.0,
                "temperature_2m_mean" => 22.5
              }
            ]
          }

          observed_dtos = [
            WeatherDatum.new(
              date: Date.new(2026, 2, 17),
              temperature_max: 8.0,
              temperature_min: -2.0,
              temperature_mean: 3.0,
              precipitation: 0.0,
              sunshine_hours: nil,
              wind_speed: 0.0,
              weather_code: 0
            ),
            WeatherDatum.new(
              date: Date.new(2026, 5, 30),
              temperature_max: 24.0,
              temperature_min: 14.0,
              temperature_mean: 19.0,
              precipitation: 0.0,
              sunshine_hours: nil,
              wind_speed: 0.0,
              weather_code: 0
            )
          ]

          merged = FieldCultivationClimateAgrrWeatherAssembler.assemble_plan_weather_with_observed(
            cached_weather_payload: cached,
            observed_weather_dtos: observed_dtos,
            weather_location_meta: weather_location_meta,
            cultivation_start_date: Date.new(2026, 2, 17),
            cultivation_end_date: Date.new(2026, 7, 13),
            today: Date.new(2026, 5, 31),
            display_start_date: Date.new(2026, 7, 1),
            display_end_date: Date.new(2026, 7, 31)
          )

          times = merged["data"].map { |datum| Date.parse(datum["time"]) }
          assert_includes times, Date.new(2026, 2, 17)
          assert_includes times, Date.new(2026, 5, 30)
          assert_includes times, Date.new(2026, 5, 31)
          assert_equal 19.0, merged["data"].find { |d| d["time"] == "2026-05-30" }["temperature_2m_mean"]
        end
      end
    end
  end
end
