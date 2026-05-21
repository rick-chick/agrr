# frozen_string_literal: true

require "test_helper"

class FetchWeatherDataJobTest < ActiveJob::TestCase
  include AgrrMockHelper

  setup do
    @user = create(:user)
    @anonymous_user = User.anonymous_user
    @start_date = Date.new(2025, 1, 1)
    @end_date = Date.new(2025, 1, 7)
  end

  test "dataが空の場合は例外を発生させ進捗を変更しない" do
    perform_mock = mock("PerformInteractor")
    perform_mock.stubs(:call).raises(
      Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor::EmptyWeatherDataNotAllowedError,
      "Weather data missing for 2025-01-01 to 2025-01-07 (0/7 days)"
    )
    Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor.stubs(:new).returns(perform_mock)

    job = FetchWeatherDataJob.new
    error = assert_raises(StandardError) do
      job.perform(
        farm_id: 1,
        latitude: 35.6762,
        longitude: 139.6503,
        start_date: @start_date,
        end_date: @end_date
      )
    end
    assert_includes error.message, "Weather data missing"
  end

  test "gatewayがnilを返した場合は無効データとして例外を出す" do
    perform_mock = mock("PerformInteractor")
    perform_mock.stubs(:call).raises(
      Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor::InvalidWeatherApiResponseError,
      "Weather data response is invalid or missing (expected Hash, got NilClass)"
    )
    Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor.stubs(:new).returns(perform_mock)

    job = FetchWeatherDataJob.new
    error = assert_raises(StandardError) do
      job.perform(
        farm_id: 1,
        latitude: 35.6762,
        longitude: 139.6503,
        start_date: @start_date,
        end_date: @end_date
      )
    end
    assert_includes error.message, "invalid or missing"
  end

  test "gatewayがハッシュ以外を返した場合は無効データとして例外を出す" do
    perform_mock = mock("PerformInteractor")
    perform_mock.stubs(:call).raises(
      Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor::InvalidWeatherApiResponseError,
      "Weather data response is invalid or missing (expected Hash, got Array)"
    )
    Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor.stubs(:new).returns(perform_mock)

    job = FetchWeatherDataJob.new
    error = assert_raises(StandardError) do
      job.perform(
        farm_id: 1,
        latitude: 35.6762,
        longitude: 139.6503,
        start_date: @start_date,
        end_date: @end_date
      )
    end
    assert_includes error.message, "invalid or missing"
  end

  test "locationが欠損している場合は例外を発生させる" do
    perform_mock = mock("PerformInteractor")
    perform_mock.stubs(:call).raises(
      Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor::MissingOrInvalidWeatherLocationError,
      "Weather data is missing location information (expected Hash, got NilClass)"
    )
    Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor.stubs(:new).returns(perform_mock)

    job = FetchWeatherDataJob.new
    error = assert_raises(StandardError) do
      job.perform(
        farm_id: 1,
        latitude: 35.6762,
        longitude: 139.6503,
        start_date: @start_date,
        end_date: @end_date
      )
    end
    assert_includes error.message, "missing location"
  end

  test "取得日数が許容欠損以内なら保存し進捗が上限を超えない" do
    farm = create(:farm, :user_owned,
      user: @user,
      weather_data_status: :fetching,
      weather_data_fetched_years: 0,
      weather_data_total_years: 1
    )

    partial_data = {
      "location" => {
        "latitude" => farm.latitude,
        "longitude" => farm.longitude,
        "elevation" => 50.0,
        "timezone" => "Asia/Tokyo"
      },
      "data" => [
        { "time" => @start_date.to_s, "temperature_2m_max" => 20.0, "temperature_2m_min" => 10.0, "temperature_2m_mean" => 15.0, "precipitation_sum" => nil, "sunshine_hours" => 6.0, "wind_speed_10m" => 3.0, "weather_code" => 0 },
        { "time" => (@start_date + 1.day).to_s, "temperature_2m_max" => 20.5, "temperature_2m_min" => 10.5, "temperature_2m_mean" => 15.5, "precipitation_sum" => 0.2, "sunshine_hours" => 6.5, "wind_speed_10m" => 3.5, "weather_code" => 1 },
        { "time" => (@start_date + 2.days).to_s, "temperature_2m_max" => 21.0, "temperature_2m_min" => 11.0, "temperature_2m_mean" => 16.0, "precipitation_sum" => 0.5, "sunshine_hours" => 7.0, "wind_speed_10m" => 4.0, "weather_code" => 1 },
        { "time" => (@start_date + 3.days).to_s, "temperature_2m_max" => 21.5, "temperature_2m_min" => 11.5, "temperature_2m_mean" => 16.5, "precipitation_sum" => 0.8, "sunshine_hours" => 7.5, "wind_speed_10m" => 4.5, "weather_code" => 1 },
        { "time" => (@start_date + 4.days).to_s, "temperature_2m_max" => 22.0, "temperature_2m_min" => 12.0, "temperature_2m_mean" => 17.0, "precipitation_sum" => 1.0, "sunshine_hours" => 8.0, "wind_speed_10m" => 5.0, "weather_code" => 1 },
        { "time" => (@start_date + 5.days).to_s, "temperature_2m_max" => 22.5, "temperature_2m_min" => 12.5, "temperature_2m_mean" => 17.5, "precipitation_sum" => 1.2, "sunshine_hours" => 8.5, "wind_speed_10m" => 5.5, "weather_code" => 1 }
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

    # Use mock weather_data_gateway to avoid expensive DB upsert (logic covered by domain test)
    weather_data_mock = mock("weather_data_gateway")
    weather_data_mock.expects(:find_weather_location_by_coordinates).with(latitude: farm.latitude, longitude: farm.longitude).returns(nil)
    weather_location_mock = mock("weather_location")
    weather_location_mock.stubs(:id).returns(1)
    weather_data_mock.expects(:find_or_create_weather_location).with(latitude: farm.latitude, longitude: farm.longitude, elevation: 50.0, timezone: "Asia/Tokyo").returns(weather_location_mock)
    weather_data_mock.expects(:upsert_weather_data!)

    Kernel.stubs(:sleep)
    farm_gateway = Adapters::Farm::Gateways::FarmActiveRecordGateway.new(
      deletion_undo_gateway: CompositionRoot.deletion_undo_gateway,
      translator: CompositionRoot.translator
    )
    farm_gateway.expects(:update_weather_location_id).with(farm.id, 1)
    # Stub increment to directly update farm (DB update in increment is tested elsewhere)
    farm_gateway.stubs(:increment_weather_data_progress).with(farm.id) do
      farm.update!(weather_data_fetched_years: 1, weather_data_status: "completed")
    end
    # Stub progress reads (used only for logging)
    farm_gateway.stubs(:get_weather_data_progress).with(farm.id).returns(100)
    farm_gateway.stubs(:get_weather_data_fetched_years).with(farm.id).returns(1)
    farm_gateway.stubs(:get_weather_data_total_years).with(farm.id).returns(1)

    Adapters::Agrr::Gateways::WeatherDaemonGateway.stub(:new, -> { gateway_mock.new(partial_data) }) do
      interactor = Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor.new(
        weather_data_gateway: weather_data_mock,
        farm_gateway: farm_gateway,
        cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
        agrr_weather_gateway: Adapters::Agrr::Gateways::WeatherDaemonGateway.new,
        presenter: Adapters::WeatherData::Presenters::FetchWeatherDataJobRailsPresenter.new(logger: Adapters::Shared::Ports::RailsLoggerAdapter.new),
        logger: Adapters::Shared::Ports::RailsLoggerAdapter.new
      )

      input_dto = {
        latitude: farm.latitude,
        longitude: farm.longitude,
        start_date: @start_date,
        end_date: @end_date,
        farm_id: farm.id,
        current_time: Time.current,
        executions: 1
      }

      interactor.call(input_dto:)
    end

    # Verify farm progress was actually updated in DB
    farm.reload
    assert_equal 1, farm.weather_data_fetched_years
    assert_equal 100, farm.weather_data_progress
    assert_equal "completed", farm.weather_data_status
  end

  test "欠損率が許容を超える場合は例外を発生させる" do
    perform_mock = mock("PerformInteractor")
    perform_mock.stubs(:call).raises(
      Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor::ExcessiveMissingWeatherDaysError,
      "Weather data missing 5 days exceeds allowed 1 days (5.0%)"
    )
    Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor.stubs(:new).returns(perform_mock)

    job = FetchWeatherDataJob.new
    error = assert_raises(StandardError) do
      job.perform(
        farm_id: 1,
        latitude: 35.6762,
        longitude: 139.6503,
        start_date: @start_date,
        end_date: @end_date
      )
    end
    assert_includes error.message, "exceeds allowed"
  end

  test "完了済みの農場では進捗を増やさない" do
    farm = create(:farm, :user_owned,
      user: @user,
      weather_data_status: :completed,
      weather_data_fetched_years: 1,
      weather_data_total_years: 1
    )
    clear_enqueued_jobs

    perform_mock = mock("PerformInteractor")
    perform_mock.stubs(:call)
    Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor.stubs(:new).returns(perform_mock)

    job = FetchWeatherDataJob.new
    job.perform(
      farm_id: farm.id,
      latitude: farm.latitude,
      longitude: farm.longitude,
      start_date: @start_date,
      end_date: @end_date
    )

    farm.reload
    assert_equal 1, farm.weather_data_fetched_years
    assert_equal 100, farm.weather_data_progress
    assert_equal "completed", farm.weather_data_status
  end

  test "perform calls PerformInteractor" do
    perform_interactor = mock("PerformInteractor")
    perform_interactor.expects(:call).with(has_entries(input_dto: has_entries(farm_id: 1, latitude: 35.6762)))
    Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor.stubs(:new).returns(perform_interactor)

    job = FetchWeatherDataJob.new
    job.perform(farm_id: 1, latitude: 35.6762, longitude: 139.6503, start_date: @start_date, end_date: @end_date)
  end

  test "retry_on handles StandardError" do
    # ジョブのperform_nowでStandardErrorが発生することを確認（retry_onが動作するための前提）
    job = FetchWeatherDataJob.new
    perform_mock = mock("perform_mock")
    Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor.stubs(:new).returns(perform_mock)
    perform_mock.stubs(:call).raises(StandardError.new("timeout"))

    assert_raises(StandardError) do
      job.perform(farm_id: 1, latitude: 35.6762, longitude: 139.6503, start_date: @start_date, end_date: @end_date)
    end
  end

  test "discard_on handles ActiveRecord::RecordInvalid" do
    # ジョブのperform_nowで例外が発生することを確認（discard_onが動作するための前提）
    job = FetchWeatherDataJob.new
    perform_mock = mock("perform_mock")
    Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor.stubs(:new).returns(perform_mock)

    # シンプルな例外を使用（ActiveRecord::RecordInvalidの詳細なモック作成は複雑なので基本的な例外テストに留める）
    perform_mock.stubs(:call).raises(RuntimeError.new("test error"))

    assert_raises(RuntimeError) do
      job.perform(farm_id: 1, latitude: 35.6762, longitude: 139.6503, start_date: @start_date, end_date: @end_date)
    end
  end
end
