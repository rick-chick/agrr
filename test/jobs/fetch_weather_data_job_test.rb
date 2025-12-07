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

  test 'regionがnilの農場でも日本の座標ならdata_sourceがjmaになる' do
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
    assert_equal 'jma', job.send(:determine_data_source, farm_without_region.id)
  end

  test 'farm_idがnilでも日本の座標ならdata_sourceがjmaになる' do
    job = FetchWeatherDataJob.new
    job.farm_id = nil
    job.latitude = 35.6762
    job.longitude = 139.6503
    job.start_date = @start_date
    job.end_date = @end_date

    # determine_data_sourceメソッドをテスト
    assert_equal 'jma', job.send(:determine_data_source, nil)
  end

  test '存在しないfarm_idでも日本の座標ならdata_sourceがjmaになる' do
    job = FetchWeatherDataJob.new
    job.farm_id = 99999  # 存在しないID
    job.latitude = 35.6762
    job.longitude = 139.6503
    job.start_date = @start_date
    job.end_date = @end_date

    # determine_data_sourceメソッドをテスト
    assert_equal 'jma', job.send(:determine_data_source, 99999)
  end

  test '日本境界外の座標（韓国付近）はnoaaになる' do
    job = FetchWeatherDataJob.new
    job.latitude = 37.5665   # Seoul
    job.longitude = 126.9780
    job.start_date = @start_date
    job.end_date = @end_date

    assert_equal 'noaa', job.send(:determine_data_source, nil)
  end

  test 'dataが空の場合は例外を発生させ進捗を変更しない' do
    farm = create(:farm, :user_owned,
      user: @user,
      weather_data_status: :fetching,
      weather_data_fetched_years: 0,
      weather_data_total_years: 1
    )
    clear_enqueued_jobs

    empty_data = {
      'location' => {
        'latitude' => farm.latitude,
        'longitude' => farm.longitude,
        'elevation' => 50.0,
        'timezone' => 'Asia/Tokyo'
      },
      'data' => []
    }

    gateway_mock = Class.new do
      def initialize(empty_data)
        @empty_data = empty_data
      end

      def fetch_by_date_range(latitude:, longitude:, start_date:, end_date:, data_source:)
        @empty_data
      end
    end

    Agrr::WeatherGateway.stub(:new, -> { gateway_mock.new(empty_data) }) do
      job = FetchWeatherDataJob.new
      error = assert_raises(StandardError) do
        job.perform(
          farm_id: farm.id,
          latitude: farm.latitude,
          longitude: farm.longitude,
          start_date: @start_date,
          end_date: @end_date
        )
      end
      assert_includes error.message, 'Weather data missing'
    end

    farm.reload
    assert_equal 0, farm.weather_data_fetched_years
    assert_equal 'fetching', farm.weather_data_status
  end

  test 'gatewayがnilを返した場合は無効データとして例外を出す' do
    farm = create(:farm, :user_owned,
      user: @user,
      weather_data_status: :fetching,
      weather_data_fetched_years: 0,
      weather_data_total_years: 1
    )
    clear_enqueued_jobs

    gateway_mock = Class.new do
      def fetch_by_date_range(latitude:, longitude:, start_date:, end_date:, data_source:)
        nil
      end
    end

    Agrr::WeatherGateway.stub(:new, -> { gateway_mock.new }) do
      job = FetchWeatherDataJob.new
      error = assert_raises(StandardError) do
        job.perform(
          farm_id: farm.id,
          latitude: farm.latitude,
          longitude: farm.longitude,
          start_date: @start_date,
          end_date: @end_date
        )
      end
      assert_includes error.message, 'invalid or missing'
    end
  end

  test 'gatewayがハッシュ以外を返した場合は無効データとして例外を出す' do
    farm = create(:farm, :user_owned,
      user: @user,
      weather_data_status: :fetching,
      weather_data_fetched_years: 0,
      weather_data_total_years: 1
    )
    clear_enqueued_jobs

    gateway_mock = Class.new do
      def initialize(response)
        @response = response
      end

      def fetch_by_date_range(latitude:, longitude:, start_date:, end_date:, data_source:)
        @response
      end
    end

    Agrr::WeatherGateway.stub(:new, -> { gateway_mock.new([]) }) do
      job = FetchWeatherDataJob.new
      error = assert_raises(StandardError) do
        job.perform(
          farm_id: farm.id,
          latitude: farm.latitude,
          longitude: farm.longitude,
          start_date: @start_date,
          end_date: @end_date
        )
      end
      assert_includes error.message, 'invalid or missing'
    end
  end

  test 'locationが欠損している場合は例外を発生させる' do
    farm = create(:farm, :user_owned,
      user: @user,
      weather_data_status: :fetching,
      weather_data_fetched_years: 0,
      weather_data_total_years: 1
    )
    clear_enqueued_jobs

    broken_data = {
      'location' => nil,
      'data' => [
        {
          'time' => @start_date.to_s,
          'temperature_2m_max' => 20.0,
          'temperature_2m_min' => 10.0,
          'temperature_2m_mean' => 15.0,
          'precipitation_sum' => nil,
          'sunshine_hours' => 6.0,
          'wind_speed_10m' => 3.0,
          'weather_code' => 0
        }
      ]
    }

    gateway_mock = Class.new do
      def initialize(broken_data)
        @broken_data = broken_data
      end

      def fetch_by_date_range(latitude:, longitude:, start_date:, end_date:, data_source:)
        @broken_data
      end
    end

    Agrr::WeatherGateway.stub(:new, -> { gateway_mock.new(broken_data) }) do
      job = FetchWeatherDataJob.new
      assert_raises(StandardError) do
        job.perform(
          farm_id: farm.id,
          latitude: farm.latitude,
          longitude: farm.longitude,
          start_date: @start_date,
          end_date: @end_date
        )
      end
    end
  end

  test '取得日数が許容欠損以内なら保存し進捗が上限を超えない' do
    farm = create(:farm, :user_owned,
      user: @user,
      weather_data_status: :fetching,
      weather_data_fetched_years: 0,
      weather_data_total_years: 1
    )
    clear_enqueued_jobs
    farm.update!(
      weather_data_status: :fetching,
      weather_data_fetched_years: 0,
      weather_data_total_years: 1
    )

    partial_data = {
      'location' => {
        'latitude' => farm.latitude,
        'longitude' => farm.longitude,
        'elevation' => 50.0,
        'timezone' => 'Asia/Tokyo'
      },
      'data' => [
        {
          'time' => @start_date.to_s,
          'temperature_2m_max' => 20.0,
          'temperature_2m_min' => 10.0,
          'temperature_2m_mean' => 15.0,
          'precipitation_sum' => nil,
          'sunshine_hours' => 6.0,
          'wind_speed_10m' => 3.0,
          'weather_code' => 0
        },
        {
          'time' => (@start_date + 1.day).to_s,
          'temperature_2m_max' => 20.5,
          'temperature_2m_min' => 10.5,
          'temperature_2m_mean' => 15.5,
          'precipitation_sum' => 0.2,
          'sunshine_hours' => 6.5,
          'wind_speed_10m' => 3.5,
          'weather_code' => 1
        },
        {
          'time' => (@start_date + 2.days).to_s,
          'temperature_2m_max' => 21.0,
          'temperature_2m_min' => 11.0,
          'temperature_2m_mean' => 16.0,
          'precipitation_sum' => 0.5,
          'sunshine_hours' => 7.0,
          'wind_speed_10m' => 4.0,
          'weather_code' => 1
        },
        {
          'time' => (@start_date + 3.days).to_s,
          'temperature_2m_max' => 21.5,
          'temperature_2m_min' => 11.5,
          'temperature_2m_mean' => 16.5,
          'precipitation_sum' => 0.8,
          'sunshine_hours' => 7.5,
          'wind_speed_10m' => 4.5,
          'weather_code' => 1
        },
        {
          'time' => (@start_date + 4.days).to_s,
          'temperature_2m_max' => 22.0,
          'temperature_2m_min' => 12.0,
          'temperature_2m_mean' => 17.0,
          'precipitation_sum' => 1.0,
          'sunshine_hours' => 8.0,
          'wind_speed_10m' => 5.0,
          'weather_code' => 1
        },
        {
          'time' => (@start_date + 5.days).to_s,
          'temperature_2m_max' => 22.5,
          'temperature_2m_min' => 12.5,
          'temperature_2m_mean' => 17.5,
          'precipitation_sum' => 1.2,
          'sunshine_hours' => 8.5,
          'wind_speed_10m' => 5.5,
          'weather_code' => 1
        }
        # 1日欠損（許容範囲内）
      ]
    }

    gateway_mock = Class.new do
      def initialize(partial_data)
        @partial_data = partial_data
      end

      def fetch_by_date_range(latitude:, longitude:, start_date:, end_date:, data_source:)
        @partial_data
      end
    end

    Agrr::WeatherGateway.stub(:new, -> { gateway_mock.new(partial_data) }) do
      FetchWeatherDataJob.perform_now(
        farm_id: farm.id,
        latitude: farm.latitude,
        longitude: farm.longitude,
        start_date: @start_date,
        end_date: @end_date
      )
    end

    weather_location = WeatherLocation.last
    assert_equal 6, WeatherDatum.where(weather_location: weather_location).count
    farm.reload
    assert_equal 1, farm.weather_data_fetched_years
    assert_equal 100, farm.weather_data_progress
    assert_equal 'completed', farm.weather_data_status
  end

  test '欠損率が許容を超える場合は例外を発生させる' do
    farm = create(:farm, :user_owned,
      user: @user,
      weather_data_status: :fetching,
      weather_data_fetched_years: 0,
      weather_data_total_years: 1
    )
    clear_enqueued_jobs

    heavily_missing = {
      'location' => {
        'latitude' => farm.latitude,
        'longitude' => farm.longitude,
        'elevation' => 50.0,
        'timezone' => 'Asia/Tokyo'
      },
      'data' => [
        {
          'time' => @start_date.to_s,
          'temperature_2m_max' => 20.0,
          'temperature_2m_min' => 10.0,
          'temperature_2m_mean' => 15.0,
          'precipitation_sum' => nil,
          'sunshine_hours' => 6.0,
          'wind_speed_10m' => 3.0,
          'weather_code' => 0
        },
        {
          'time' => (@start_date + 1.day).to_s,
          'temperature_2m_max' => 21.0,
          'temperature_2m_min' => 11.0,
          'temperature_2m_mean' => 16.0,
          'precipitation_sum' => 0.5,
          'sunshine_hours' => 7.0,
          'wind_speed_10m' => 4.0,
          'weather_code' => 1
        }
        # 残り5日欠損（許容1日を超過）
      ]
    }

    gateway_mock = Class.new do
      def initialize(heavily_missing)
        @heavily_missing = heavily_missing
      end

      def fetch_by_date_range(latitude:, longitude:, start_date:, end_date:, data_source:)
        @heavily_missing
      end
    end

    Agrr::WeatherGateway.stub(:new, -> { gateway_mock.new(heavily_missing) }) do
      job = FetchWeatherDataJob.new
      assert_raises(StandardError) do
        job.perform(
          farm_id: farm.id,
          latitude: farm.latitude,
          longitude: farm.longitude,
          start_date: @start_date,
          end_date: @end_date
        )
      end
    end
  end

  test '完了済みの農場では進捗を増やさない' do
    farm = create(:farm, :user_owned,
      user: @user,
      weather_data_status: :completed,
      weather_data_fetched_years: 1,
      weather_data_total_years: 1
    )
    clear_enqueued_jobs
    farm.update!(
      weather_data_status: :completed,
      weather_data_fetched_years: 1,
      weather_data_total_years: 1
    )

    minimal_data = {
      'location' => {
        'latitude' => farm.latitude,
        'longitude' => farm.longitude,
        'elevation' => 50.0,
        'timezone' => 'Asia/Tokyo'
      },
      'data' => [
        {
          'time' => @start_date.to_s,
          'temperature_2m_max' => 20.0,
          'temperature_2m_min' => 10.0,
          'temperature_2m_mean' => 15.0,
          'precipitation_sum' => nil,
          'sunshine_hours' => 6.0,
          'wind_speed_10m' => 3.0,
          'weather_code' => 0
        }
      ]
    }

    gateway_mock = Class.new do
      def initialize(minimal_data)
        @minimal_data = minimal_data
      end

      def fetch_by_date_range(latitude:, longitude:, start_date:, end_date:, data_source:)
        @minimal_data
      end
    end

    Agrr::WeatherGateway.stub(:new, -> { gateway_mock.new(minimal_data) }) do
      FetchWeatherDataJob.perform_now(
        farm_id: farm.id,
        latitude: farm.latitude,
        longitude: farm.longitude,
        start_date: @start_date,
        end_date: @end_date
      )
    end

    farm.reload
    assert_equal 1, farm.weather_data_fetched_years
    assert_equal 100, farm.weather_data_progress
    assert_equal 'completed', farm.weather_data_status
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

