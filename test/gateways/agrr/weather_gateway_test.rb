# frozen_string_literal: true

require 'test_helper'

class AgrrWeatherGatewayTest < ActiveSupport::TestCase
  class StubAgrrService
    attr_reader :received_args

    def initialize
      @response = {
        'data' => [
          {
            'time' => '2025-01-01T00:00:00',
            'temperature_2m_mean' => 16.5
          }
        ],
        'location' => {
          'latitude' => 35.0,
          'longitude' => 139.0
        }
      }
    end

    def weather(location:, start_date: nil, end_date: nil, days: nil, data_source: 'noaa', json: true)
      @received_args = {
        location: location,
        start_date: start_date,
        end_date: end_date,
        days: days,
        data_source: data_source,
        json: json
      }

      # outputオプションが使われている場合、ファイルに書き込む
      if @received_args[:output_path]
        File.write(@received_args[:output_path], @response.to_json)
      end

      @response.to_json
    end
  end

  def setup
    load Rails.root.join('app/gateways/agrr/weather_gateway.rb')
    @gateway = Agrr::WeatherGateway.new
    @stub_service = StubAgrrService.new
    @gateway.instance_variable_set(:@agrr_service, @stub_service)
    # 環境変数をクリーンアップ
    @original_weather_data_source = ENV.delete('WEATHER_DATA_SOURCE')
  end

  def teardown
    # 環境変数を復元
    if @original_weather_data_source
      ENV['WEATHER_DATA_SOURCE'] = @original_weather_data_source
    end
  end

  test 'fetch_by_date_range calls agrr service with start_date and end_date' do
    start_date = Date.new(2025, 1, 1)
    end_date = Date.new(2025, 1, 31)

    result = @gateway.fetch_by_date_range(
      latitude: 35.0,
      longitude: 139.0,
      start_date: start_date,
      end_date: end_date
    )

    assert_not_nil @stub_service.received_args
    assert_equal '35.0,139.0', @stub_service.received_args[:location]
    assert_equal start_date.to_s, @stub_service.received_args[:start_date]
    assert_equal end_date.to_s, @stub_service.received_args[:end_date]
    assert_nil @stub_service.received_args[:days]
    assert_equal 'noaa', @stub_service.received_args[:data_source]

    assert_equal 1, result['data'].count
    assert_equal '2025-01-01T00:00:00', result['data'].first['time']
  end

  test 'fetch_by_date_range respects WEATHER_DATA_SOURCE environment variable' do
    start_date = Date.new(2025, 1, 1)
    end_date = Date.new(2025, 1, 31)

    ENV['WEATHER_DATA_SOURCE'] = 'nasa-power'
    begin
      # 新しいゲートウェイインスタンスを作成して環境変数を反映
      gateway = Agrr::WeatherGateway.new
      stub_service = StubAgrrService.new
      gateway.instance_variable_set(:@agrr_service, stub_service)

      gateway.fetch_by_date_range(
        latitude: 35.0,
        longitude: 139.0,
        start_date: start_date,
        end_date: end_date
      )

      assert_equal 'nasa-power', stub_service.received_args[:data_source]
    ensure
      ENV.delete('WEATHER_DATA_SOURCE')
    end
  end
end

