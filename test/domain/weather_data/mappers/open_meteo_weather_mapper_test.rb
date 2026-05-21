# frozen_string_literal: true

require "domain_lib_test_helper"

class OpenMeteoWeatherMapperTest < DomainLibTestCase
  test "format_for_agrr builds agrr hash" do
    dto = Domain::WeatherData::Dtos::WeatherData.new(date: Date.new(2023, 1, 1), temperature_max: 10.0)
    result = Domain::WeatherData::Mappers::OpenMeteoWeatherMapper.format_for_agrr(
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
