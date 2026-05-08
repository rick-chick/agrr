# frozen_string_literal: true

require "test_helper"

class OpenMeteoWeatherPayloadTest < ActiveSupport::TestCase
  test "normalize_raw_payload returns nil for blankish inputs" do
    assert_nil Domain::WeatherData::Services::OpenMeteoWeatherPayload.normalize_raw_payload(nil)
    assert_nil Domain::WeatherData::Services::OpenMeteoWeatherPayload.normalize_raw_payload({})
    assert_nil Domain::WeatherData::Services::OpenMeteoWeatherPayload.normalize_raw_payload([])
    assert_nil Domain::WeatherData::Services::OpenMeteoWeatherPayload.normalize_raw_payload("   ")
  end

  test "normalize_raw_payload unwraps legacy nested payload" do
    inner = { "data" => [] }
    raw = { "data" => inner }
    assert_equal inner, Domain::WeatherData::Services::OpenMeteoWeatherPayload.normalize_raw_payload(raw)
  end

  test "normalize_raw_payload returns standard payload as-is" do
    raw = { "data" => [ { "time" => "2023-01-01" } ] }
    assert_equal raw, Domain::WeatherData::Services::OpenMeteoWeatherPayload.normalize_raw_payload(raw)
  end

  test "format_for_agrr builds agrr hash" do
    dto = Domain::WeatherData::Dtos::WeatherDataDto.new(date: Date.new(2023, 1, 1), temperature_max: 10.0)
    result = Domain::WeatherData::Services::OpenMeteoWeatherPayload.format_for_agrr(
      weather_data_dtos: [ dto ],
      latitude: 35.0,
      longitude: 139.0,
      elevation: nil,
      timezone: "UTC"
    )
    assert_equal 35.0, result["latitude"]
    assert_equal 139.0, result["longitude"]
    assert_equal 0.0, result["elevation"]
    assert_equal "UTC", result["timezone"]
    assert_equal 1, result["data"].size
  end
end
