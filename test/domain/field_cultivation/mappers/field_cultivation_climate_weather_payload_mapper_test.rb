# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Mappers
      class FieldCultivationClimateWeatherPayloadMapperTest < DomainLibTestCase
        WeatherDatum = Struct.new(
          :date, :temperature_max, :temperature_min, :temperature_mean,
          :precipitation, :sunshine_hours, :wind_speed, :weather_code,
          keyword_init: true
        )

        test "coerce_optional_date normalizes values" do
          d = Date.new(2024, 6, 1)
          assert_equal d, FieldCultivationClimateWeatherPayloadMapper.coerce_optional_date(d)
          assert_equal d, FieldCultivationClimateWeatherPayloadMapper.coerce_optional_date("2024-06-01")
          assert_nil FieldCultivationClimateWeatherPayloadMapper.coerce_optional_date(nil)
          assert_nil FieldCultivationClimateWeatherPayloadMapper.coerce_optional_date("not-a-date")
        end

        test "merge_cached_with_observed overwrites by date key" do
          cached = {
            "data" => [
              { "time" => "2024-06-01", "temperature_2m_mean" => 10.0 }
            ]
          }
          observed = {
            "data" => [
              { "time" => "2024-06-01", "temperature_2m_mean" => 20.0 },
              { "time" => "2024-06-02", "temperature_2m_mean" => 15.0 }
            ]
          }

          merged = FieldCultivationClimateWeatherPayloadMapper.merge_cached_with_observed(
            cached_weather_payload: cached,
            observed_formatted: observed
          )

          assert_equal 2, merged["data"].length
          assert_equal 20.0, merged["data"].find { |d| d["time"] == "2024-06-01" }["temperature_2m_mean"]
        end

        test "merge_cached_with_observed returns cached when observed empty" do
          cached = { "data" => [ { "time" => "2024-06-01" } ] }
          merged = FieldCultivationClimateWeatherPayloadMapper.merge_cached_with_observed(
            cached_weather_payload: cached,
            observed_formatted: { "data" => [] }
          )
          assert_equal cached, merged
        end
      end
    end
  end
end
