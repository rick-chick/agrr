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

    weather_location = WeatherLocation.find_by(latitude: farm.latitude, longitude: farm.longitude)
    assert_not_nil weather_location, "WeatherLocation should be created for the farm"
    gateway = Adapters::WeatherData::Gateways::ActiveRecordWeatherDataGateway.new
    assert_equal 6, gateway.weather_data_count(
      weather_location_id: weather_location.id,
      start_date: @start_date,
      end_date: @start_date + 5.days
    )
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

  test 'perform calls PerformInteractor' do
    perform_interactor = mock('PerformInteractor')
    perform_interactor.expects(:execute).with(has_entries(input_dto: has_entries(farm_id: 1, latitude: 35.6762)))
    Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor.stubs(:new).returns(perform_interactor)

    job = FetchWeatherDataJob.new
    job.perform(farm_id: 1, latitude: 35.6762, longitude: 139.6503, start_date: @start_date, end_date: @end_date)
  end

  test 'retry_on calls RetryOnInteractor' do
    retry_interactor = mock('RetryOnInteractor')
    retry_interactor.expects(:execute).with(has_entries(input_dto: has_entries(executions: 3, error_message: 'timeout')))
    Domain::WeatherData::Interactors::FetchWeatherDataRetryOnInteractor.stubs(:new).returns(retry_interactor)

    job = FetchWeatherDataJob.new
    job.executions = 3
    Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor.stubs(:new).raises(StandardError.new('timeout'))

    assert_raises(StandardError) do
      job.perform(farm_id: 1, latitude: 35.6762, longitude: 139.6503, start_date: @start_date, end_date: @end_date)
    end
  end

  test 'discard_on calls DiscardOnInteractor' do
    discard_interactor = mock('DiscardOnInteractor')
    discard_interactor.expects(:execute).with(has_entries(input_dto: has_entries(error_message: /RecordInvalid/)))
    Domain::WeatherData::Interactors::FetchWeatherDataDiscardOnInteractor.stubs(:new).returns(discard_interactor)

    job = FetchWeatherDataJob.new
    record = double('record')
    record.singleton_class.send(:define_method, :errors) { ActiveRecord::Errors.new([]) }
    Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor.stubs(:new).raises(ActiveRecord::RecordInvalid.new(record, 'invalid'))

    assert_raises(ActiveRecord::RecordInvalid) do
      job.perform(farm_id: 1, latitude: 35.6762, longitude: 139.6503, start_date: @start_date, end_date: @end_date)
    end
  end

end

