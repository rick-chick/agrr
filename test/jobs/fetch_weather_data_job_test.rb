# frozen_string_literal: true

require 'test_helper'

class FetchWeatherDataJobTest < ActiveJob::TestCase
  include AgrrMockHelper

  setup do
    @user = create(:user)
    @anonymous_user = User.anonymous_user
    @start_date = Date.new(2025, 1, 1)
    @end_date = Date.new(2025, 1, 7)
  end

  test '日本（region == jp）の農場の場合、data_sourceがjmaになる' do
    # 日本の農場を作成
    japan_farm = create(:farm, :reference,
      name: '東京農場',
      latitude: 35.6762,
      longitude: 139.6503,
      region: 'jp',
      user: @anonymous_user
    )

    job = FetchWeatherDataJob.new
    job.farm_id = japan_farm.id
    job.latitude = 35.6762
    job.longitude = 139.6503
    job.start_date = @start_date
    job.end_date = @end_date

    # determine_data_sourceメソッドをテスト
    assert_equal 'jma', job.send(:determine_data_source, japan_farm.id)
  end

  test '日本以外の農場の場合、data_sourceがnoaaになる' do
    # 日本以外の農場を作成（regionがnilまたは'jp'以外）
    us_farm = create(:farm, :reference,
      name: 'US Farm',
      latitude: 40.7128,
      longitude: -74.0060,
      region: 'us',
      user: @anonymous_user
    )

    job = FetchWeatherDataJob.new
    job.farm_id = us_farm.id
    job.latitude = 40.7128
    job.longitude = -74.0060
    job.start_date = @start_date
    job.end_date = @end_date

    # determine_data_sourceメソッドをテスト
    assert_equal 'noaa', job.send(:determine_data_source, us_farm.id)
  end

  test 'regionがnilの農場の場合、data_sourceがnasa-powerになる' do
    # regionがnilの農場を作成
    farm_without_region = create(:farm, :reference,
      name: 'Farm without region',
      latitude: 35.6762,
      longitude: 139.6503,
      region: nil,
      user: @anonymous_user
    )

    job = FetchWeatherDataJob.new
    job.farm_id = farm_without_region.id
    job.latitude = 35.6762
    job.longitude = 139.6503
    job.start_date = @start_date
    job.end_date = @end_date

    # determine_data_sourceメソッドをテスト
    assert_equal 'nasa-power', job.send(:determine_data_source, farm_without_region.id)
  end

  test 'farm_idがnilの場合、data_sourceがnoaaになる' do
    job = FetchWeatherDataJob.new
    job.farm_id = nil
    job.latitude = 35.6762
    job.longitude = 139.6503
    job.start_date = @start_date
    job.end_date = @end_date

    # determine_data_sourceメソッドをテスト
    assert_equal 'noaa', job.send(:determine_data_source, nil)
  end

  test '存在しないfarm_idの場合、data_sourceがnoaaになる' do
    job = FetchWeatherDataJob.new
    job.farm_id = 99999  # 存在しないID
    job.latitude = 35.6762
    job.longitude = 139.6503
    job.start_date = @start_date
    job.end_date = @end_date

    # determine_data_sourceメソッドをテスト
    assert_equal 'noaa', job.send(:determine_data_source, 99999)
  end

  test 'fetch_weather_from_agrrが正しいdata_sourceを渡す（日本）' do
    # 日本の農場を作成
    japan_farm = create(:farm, :reference,
      name: '東京農場',
      latitude: 35.6762,
      longitude: 139.6503,
      region: 'jp',
      user: @anonymous_user
    )

    # WeatherGatewayをモック化して、data_sourceパラメータを確認
    captured_data_source = {}
    gateway_mock = Class.new do
      def initialize(captured)
        @captured = captured
      end

      def fetch_by_date_range(latitude:, longitude:, start_date:, end_date:, data_source:)
        @captured[:data_source] = data_source
        {
          'location' => {
            'latitude' => latitude,
            'longitude' => longitude,
            'elevation' => 50.0,
            'timezone' => 'Asia/Tokyo'
          },
          'data' => []
        }
      end
    end

    Agrr::WeatherGateway.stub(:new, -> { gateway_mock.new(captured_data_source) }) do
      job = FetchWeatherDataJob.new
      job.farm_id = japan_farm.id
      job.latitude = 35.6762
      job.longitude = 139.6503
      job.start_date = @start_date
      job.end_date = @end_date

      # fetch_weather_from_agrrを呼び出す
      job.send(:fetch_weather_from_agrr, 35.6762, 139.6503, @start_date, @end_date, japan_farm.id)

      # data_sourceが'jma'であることを確認
      assert_equal 'jma', captured_data_source[:data_source]
    end
  end

  test 'fetch_weather_from_agrrが正しいdata_sourceを渡す（日本以外）' do
    # 日本以外の農場を作成
    us_farm = create(:farm, :reference,
      name: 'US Farm',
      latitude: 40.7128,
      longitude: -74.0060,
      region: 'us',
      user: @anonymous_user
    )

    # WeatherGatewayをモック化して、data_sourceパラメータを確認
    captured_data_source = {}
    gateway_mock = Class.new do
      def initialize(captured)
        @captured = captured
      end

      def fetch_by_date_range(latitude:, longitude:, start_date:, end_date:, data_source:)
        @captured[:data_source] = data_source
        {
          'location' => {
            'latitude' => latitude,
            'longitude' => longitude,
            'elevation' => 50.0,
            'timezone' => 'America/New_York'
          },
          'data' => []
        }
      end
    end

    Agrr::WeatherGateway.stub(:new, -> { gateway_mock.new(captured_data_source) }) do
      job = FetchWeatherDataJob.new
      job.farm_id = us_farm.id
      job.latitude = 40.7128
      job.longitude = -74.0060
      job.start_date = @start_date
      job.end_date = @end_date

      # fetch_weather_from_agrrを呼び出す
      job.send(:fetch_weather_from_agrr, 40.7128, -74.0060, @start_date, @end_date, us_farm.id)

      # data_sourceが'noaa'であることを確認
      assert_equal 'noaa', captured_data_source[:data_source]
    end
  end
end

