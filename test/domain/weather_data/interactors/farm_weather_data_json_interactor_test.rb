# frozen_string_literal: true

require "test_helper"

class Domain::WeatherData::Interactors::FarmWeatherDataJsonInteractorTest < ActiveSupport::TestCase
  class RecordingOutputPort < Domain::WeatherData::Ports::FarmWeatherDataJsonOutputPort
    attr_reader :calls

    def initialize
      @calls = []
    end

    def on_index_success(farm:, period:, data:)
      @calls << [ :index_success, { farm: farm, period: period, data: data } ]
    end

    def on_prediction_cached_success(farm:, period:, is_prediction:, predicted_at:, model:, data:)
      @calls << [ :prediction_cached, {} ]
    end

    def on_prediction_queued(farm_id:, farm_name:)
      @calls << [ :prediction_queued, { farm_id: farm_id, farm_name: farm_name } ]
    end

    def on_farm_not_found
      @calls << [ :farm_not_found, {} ]
    end

    def on_no_weather_location
      @calls << [ :no_weather_location, {} ]
    end

    def on_insufficient_historical_data
      @calls << [ :insufficient, {} ]
    end

    def on_enqueue_failed(error_message:)
      @calls << [ :enqueue_failed, { error_message: error_message } ]
    end
  end

  class FakeFarmGateway
    attr_accessor :ctx

    def farm_weather_data_json_context_for_owned_farm(user_id:, farm_id:)
      ctx if ctx
    end

    def farm_weather_data_json_context_for_admin_farm_lookup(farm_id:)
      ctx if ctx
    end

    def update_predicted_weather_data(farm_id, payload); end
  end

  class FakeWeatherGateway
    attr_accessor :period_count, :rows, :historical

    def initialize
      @period_count = 1
      @rows = []
      @historical = 10_000
    end

    def weather_data_count(weather_location_id:, start_date: nil, end_date: nil)
      if start_date && end_date
        period_count
      else
        0
      end
    end

    def weather_data_for_period(weather_location_id:, start_date:, end_date:)
      rows
    end

    def earliest_date(weather_location_id:)
      Date.new(2020, 1, 1)
    end

    def latest_date(weather_location_id:)
      Date.new(2024, 1, 1)
    end

    def historical_data_count(weather_location_id:, start_date:, end_date:)
      historical
    end
  end

  class FakeEnqueue
    attr_accessor :result

    def initialize
      @result = Domain::WeatherData::Ports::PredictWeatherStandaloneEnqueueResult.success
    end

    def enqueue_predict_weather_standalone(**)
      result
    end
  end

  class FakeParse
    def predicted_at_from_payload(_s)
      Time.zone.parse("2026-01-01T00:00:00Z")
    end

    def prediction_start_date_from_payload(_s)
      Date.new(2026, 1, 1)
    end
  end

  setup do
    @farm_gateway = FakeFarmGateway.new
    @weather_gateway = FakeWeatherGateway.new
    @enqueue = FakeEnqueue.new
    @parse = FakeParse.new
    @output = RecordingOutputPort.new
    @logger = Logger.new(File::NULL)
    @clock = Time.zone
    @interactor = Domain::WeatherData::Interactors::FarmWeatherDataJsonInteractor.new(
      output_port: @output,
      farm_gateway: @farm_gateway,
      weather_data_gateway: @weather_gateway,
      enqueue_port: @enqueue,
      prediction_payload_parse: @parse,
      logger: @logger,
      clock: @clock
    )
  end

  test "index builds temperature_mean from max/min when dto mean is nil (hash keys are symbols)" do
    ctx = Domain::Farm::Dtos::FarmWeatherDataJsonContextDto.new(
      farm_id: 1,
      display_name: "テスト",
      latitude: 35.0,
      longitude: 139.0,
      weather_location_id: 9,
      predicted_weather_data: nil
    )
    @farm_gateway.ctx = ctx

    row = Domain::WeatherData::Dtos::WeatherDataDto.new(
      date: Date.new(2024, 6, 1),
      temperature_max: 30.0,
      temperature_min: 20.0,
      temperature_mean: nil,
      precipitation: 1.0,
      sunshine_hours: nil,
      wind_speed: nil,
      weather_code: nil
    )
    @weather_gateway.rows = [ row ]

    input = Domain::WeatherData::Dtos::FarmWeatherDataJsonInputDto.new(
      farm_id: 1,
      user_id: 1,
      is_admin: false,
      predict: false,
      start_date: Date.new(2024, 1, 1),
      end_date: Date.new(2024, 12, 31)
    )

    @interactor.call(input)

    assert_equal :index_success, @output.calls.first.first
    payload = @output.calls.first.last
    assert_equal 25.0, payload[:data].first[:temperature_mean]
  end

  test "returns farm_not_found when gateway returns nil" do
    @farm_gateway.ctx = nil
    input = Domain::WeatherData::Dtos::FarmWeatherDataJsonInputDto.new(
      farm_id: 99,
      user_id: 1,
      is_admin: false,
      predict: false
    )
    @interactor.call(input)
    assert_equal :farm_not_found, @output.calls.first.first
  end
end
