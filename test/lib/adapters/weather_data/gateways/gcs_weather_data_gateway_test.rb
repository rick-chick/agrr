# frozen_string_literal: true

require "test_helper"
require "ostruct"

class GcsWeatherDataGatewayTest < ActiveSupport::TestCase
  # In-memory bucket mock for testing without real GCS
  class InMemoryBucket
    def initialize
      @files = {}
    end

    def file(path)
      return nil unless @files.key?(path)

      content = @files[path]
      blob = Object.new
      def blob.download
        @content
      end
      blob.instance_variable_set(:@content, content.is_a?(String) ? content : content.to_s)
      blob
    end

    def files(prefix:)
      prefix_s = prefix.to_s
      @files.select { |path, _| path.start_with?(prefix_s) }.map do |path, content|
        blob = Object.new
        def blob.download
          @content
        end
        blob.instance_variable_set(:@content, content.is_a?(String) ? content : content.to_s)
        blob
      end
    end

    def create_file(io, path, content_type: nil)
      content = io.respond_to?(:read) ? io.read : io.to_s
      @files[path] = content
    end

    def put(path, content)
      @files[path] = content
    end
  end

  setup do
    @bucket = InMemoryBucket.new
    @gateway = Adapters::WeatherData::Gateways::GcsWeatherDataGateway.new(bucket: @bucket)
    @weather_location = create(:weather_location)
    @date1 = Date.new(2023, 1, 1)
    @date2 = Date.new(2023, 1, 2)
  end

  test "weather_data_for_period returns empty when no data" do
    dtos = @gateway.weather_data_for_period(
      weather_location_id: @weather_location.id,
      start_date: @date1,
      end_date: @date2
    )
    assert_equal [], dtos
  end

  test "weather_data_for_period returns DTOs from GCS" do
    path = "weather_data/#{@weather_location.id}/2023.json"
    data = {
      "2023-01-01" => {
        "temperature_max" => 10.0,
        "temperature_min" => 5.0,
        "temperature_mean" => 7.5,
        "precipitation" => 0.0,
        "sunshine_hours" => 6.0,
        "wind_speed" => 3.0,
        "weather_code" => 0
      },
      "2023-01-02" => {
        "temperature_max" => 12.0,
        "temperature_min" => 6.0,
        "temperature_mean" => 9.0,
        "precipitation" => 0.0,
        "sunshine_hours" => 7.0,
        "wind_speed" => 4.0,
        "weather_code" => 1
      }
    }
    @bucket.put(path, data.to_json)

    dtos = @gateway.weather_data_for_period(
      weather_location_id: @weather_location.id,
      start_date: @date1,
      end_date: @date2
    )
    assert_equal 2, dtos.size
    assert_instance_of Domain::WeatherData::Dtos::WeatherDataDto, dtos.first
    assert_equal @date1, dtos.first.date
    assert_equal 10.0, dtos.first.temperature_max
  end

  test "normalize_weather_data calls AgrrService" do
    raw_data = { "data" => { "data" => [] } }
    result = @gateway.normalize_weather_data(raw_data: raw_data)
    assert_kind_of Hash, result
  end

  test "extract_weather_data_by_period extracts and converts to DTO" do
    payload = {
      "data" => [
        { "time" => "2023-01-01", "temperature_2m_max" => 10.0, "temperature_2m_min" => 5.0 }
      ]
    }
    dtos = @gateway.extract_weather_data_by_period(
      raw_weather_payload: payload,
      start_date: Date.new(2023, 1, 1),
      end_date: Date.new(2023, 1, 1)
    )
    assert_equal 1, dtos.size
    assert_equal 7.5, dtos.first.temperature_mean
  end

  test "format_for_agrr formats DTOs to AGRR hash" do
    dto = Domain::WeatherData::Dtos::WeatherDataDto.new(date: Date.new(2023, 1, 1), temperature_max: 10.0)
    location = OpenStruct.new(latitude: 35.0, longitude: 139.0, elevation: 0.0, timezone: "UTC")
    result = @gateway.format_for_agrr(weather_data_dtos: [dto], weather_location: location)
    assert_kind_of Hash, result
    assert_equal 35.0, result["latitude"]
    assert_equal 1, result["data"].size
  end

  test "weather_data_count returns correct count" do
    path = "weather_data/#{@weather_location.id}/2023.json"
    @bucket.put(path, { "2023-01-01" => {}, "2023-01-02" => {} }.to_json)
    assert_equal 2, @gateway.weather_data_count(
      weather_location_id: @weather_location.id,
      start_date: @date1,
      end_date: @date2
    )
  end

  test "upsert_weather_data! writes to GCS" do
    attrs = [{ date: Date.new(2023, 1, 3), temperature_max: 15.0, temperature_min: 10.0, temperature_mean: 12.5 }]
    dtos = attrs.map { |a| Domain::WeatherData::Dtos::WeatherDataDto.from_attrs(a) }
    @gateway.upsert_weather_data!(weather_data_dtos: dtos, weather_location_id: @weather_location.id)

    result_dtos = @gateway.weather_data_for_period(
      weather_location_id: @weather_location.id,
      start_date: Date.new(2023, 1, 3),
      end_date: Date.new(2023, 1, 3)
    )
    assert_equal 1, result_dtos.size
    assert_equal 15.0, result_dtos.first.temperature_max
  end

  test "upsert_weather_data! merges with existing" do
    path = "weather_data/#{@weather_location.id}/2023.json"
    @bucket.put(path, { "2023-01-01" => { "temperature_max" => 8.0, "temperature_min" => 4.0 } }.to_json)
    attrs = [{ date: Date.new(2023, 1, 2), temperature_max: 12.0, temperature_min: 6.0, temperature_mean: 9.0 }]
    dtos = attrs.map { |a| Domain::WeatherData::Dtos::WeatherDataDto.from_attrs(a) }
    @gateway.upsert_weather_data!(weather_data_dtos: dtos, weather_location_id: @weather_location.id)

    result_dtos = @gateway.weather_data_for_period(
      weather_location_id: @weather_location.id,
      start_date: @date1,
      end_date: Date.new(2023, 1, 2)
    )
    assert_equal 2, result_dtos.size
    assert_equal 8.0, result_dtos.find { |d| d.date == @date1 }.temperature_max
    assert_equal 12.0, result_dtos.find { |d| d.date == Date.new(2023, 1, 2) }.temperature_max
  end

  test "earliest_date returns minimum date from GCS" do
    path = "weather_data/#{@weather_location.id}/2023.json"
    @bucket.put(path, { "2023-01-02" => {}, "2023-01-01" => {} }.to_json)
    assert_equal @date1, @gateway.earliest_date(weather_location_id: @weather_location.id)
  end

  test "latest_date returns maximum date from GCS" do
    path = "weather_data/#{@weather_location.id}/2023.json"
    @bucket.put(path, { "2023-01-02" => {}, "2023-01-01" => {} }.to_json)
    assert_equal @date2, @gateway.latest_date(weather_location_id: @weather_location.id)
  end

  test "find_weather_location_by_coordinates uses WeatherLocation" do
    loc = @gateway.find_weather_location_by_coordinates(
      latitude: @weather_location.latitude,
      longitude: @weather_location.longitude
    )
    assert_equal @weather_location.id, loc.id
  end

  test "find_or_create_weather_location uses WeatherLocation" do
    loc = @gateway.find_or_create_weather_location(
      latitude: @weather_location.latitude,
      longitude: @weather_location.longitude
    )
    assert_equal @weather_location.id, loc.id
  end

  test "historical_data_count counts records with temp_max and temp_min" do
    path = "weather_data/#{@weather_location.id}/2023.json"
    @bucket.put(path, {
      "2023-01-01" => { "temperature_max" => 10.0, "temperature_min" => 5.0 },
      "2023-01-02" => { "temperature_max" => nil, "temperature_min" => 6.0 }
    }.to_json)
    count = @gateway.historical_data_count(
      weather_location_id: @weather_location.id,
      start_date: @date1,
      end_date: @date2
    )
    assert_equal 1, count
  end
end
