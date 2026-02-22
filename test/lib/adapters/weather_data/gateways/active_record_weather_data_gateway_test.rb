# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

class ActiveRecordWeatherDataGatewayTest < ActiveSupport::TestCase
  setup do
    @gateway = Adapters::WeatherData::Gateways::ActiveRecordWeatherDataGateway.new
    @weather_location = create(:weather_location)
    @date1 = Date.new(2023, 1, 1)
    @date2 = Date.new(2023, 1, 2)
    @weather_datum1 = create(:weather_datum, weather_location: @weather_location, date: @date1)
    @weather_datum2 = create(:weather_datum, weather_location: @weather_location, date: @date2)
  end

  test 'weather_data_for_period returns DTO array' do
    dtos = @gateway.weather_data_for_period(
      weather_location_id: @weather_location.id,
      start_date: @date1,
      end_date: @date2
    )
    assert_equal 2, dtos.size
    assert_instance_of Domain::WeatherData::Dtos::WeatherDataDto, dtos.first
    assert_equal @date1, dtos.first.date
  end

  test 'normalize_weather_data calls AgrrService' do
    raw_data = { 'data' => { 'data' => [] } }
    result = @gateway.normalize_weather_data(raw_data: raw_data)
    assert_kind_of Hash, result
  end

  test 'extract_weather_data_by_period extracts and converts to DTO' do
    payload = {
      'data' => [
        { 'time' => '2023-01-01', 'temperature_2m_max' => 10.0, 'temperature_2m_min' => 5.0 }
      ]
    }
    dtos = @gateway.extract_weather_data_by_period(
      raw_weather_payload: payload,
      start_date: Date.new(2023,1,1),
      end_date: Date.new(2023,1,1)
    )
    assert_equal 1, dtos.size
    assert_equal 7.5, dtos.first.temperature_mean
  end

  test 'format_for_agrr formats DTOs to AGRR hash' do
    dto = Domain::WeatherData::Dtos::WeatherDataDto.new(date: Date.new(2023,1,1), temperature_max: 10.0)
    location = OpenStruct.new(latitude: 35.0, longitude: 139.0, timezone: 'UTC')
    result = @gateway.format_for_agrr(weather_data_dtos: [dto], weather_location: location)
    assert_kind_of Hash, result
    assert_equal [35.0, 139.0, 0.0, 'UTC', [{'time'=>'2023-01-01', 'temperature_2m_max'=>10.0, 'temperature_2m_min'=>nil, 'temperature_2m_mean'=>nil, 'precipitation_sum'=>nil, 'sunshine_duration'=>0.0, 'wind_speed_10m_max'=>nil, 'weather_code'=>nil}]], result.values
  end

  test 'weather_data_count returns correct count' do
    assert_equal 2, @gateway.weather_data_count(
      weather_location_id: @weather_location.id,
      start_date: @date1,
      end_date: @date2
    )
  end

  test 'upsert_weather_data! upserts records' do
    attrs = [{ date: Date.new(2023,1,3), temperature_max: 15.0, temperature_min: 10.0, temperature_mean: 12.5 }]
    dtos = attrs.map { |a| Domain::WeatherData::Dtos::WeatherDataDto.from_attrs(a) }
    @gateway.upsert_weather_data!(weather_data_dtos: dtos, weather_location_id: @weather_location.id)

    result_dtos = @gateway.weather_data_for_period(weather_location_id: @weather_location.id, start_date: Date.new(2023,1,3), end_date: Date.new(2023,1,3))
    assert_equal 1, result_dtos.size
    assert_equal 15.0, result_dtos.first.temperature_max
  end

  test 'earliest_date returns minimum date' do
    assert_equal @date1, @gateway.earliest_date(weather_location_id: @weather_location.id)
  end

  test 'latest_date returns maximum date' do
    assert_equal @date2, @gateway.latest_date(weather_location_id: @weather_location.id)
  end
end
