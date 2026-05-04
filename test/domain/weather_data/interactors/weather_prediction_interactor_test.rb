# frozen_string_literal: true

require "test_helper"

class WeatherPredictionInteractorTest < ActiveSupport::TestCase
  FakeClock = Struct.new(:frozen_date, :frozen_time, keyword_init: true) do
    def today
      frozen_date
    end

    def now
      frozen_time
    end
  end

  setup do
    @weather_prediction_clock = FakeClock.new(
      frozen_date: Date.new(2026, 5, 15),
      frozen_time: Time.utc(2026, 5, 15, 8, 0, 0)
    )
    @anchors_resolver = Adapters::WeatherData::RailsWeatherPredictionAnchorsResolver.new(zone: Time.zone)
    @weather_location = create(:weather_location)
    @user = create(:user)
    @farm = create(:farm, user: @user, weather_location: @weather_location)

    tr = Adapters::Translators::RailsTranslator.new
    deletion_undo = Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGateway.new
    @cultivation_plan_gateway = Adapters::CultivationPlan::Gateways::CultivationPlanActiveRecordGateway.new(translator: tr)
    @farm_gateway = Adapters::Farm::Gateways::FarmActiveRecordGateway.new(
      deletion_undo_gateway: deletion_undo,
      translator: tr
    )
    @weather_data_gateway = Adapters::WeatherData::Gateways::ActiveRecordWeatherDataGateway.new
    @prediction_gateway = Adapters::WeatherData::Gateways::AgrrPredictionGatewayAdapter.new
    @weather_prediction_logger = Adapters::Logger::Gateways::RailsLoggerGateway.new
  end

  def weather_location_dto(loc = @weather_location)
    Domain::WeatherData::Dtos::WeatherLocationDto.new(
      id: loc.id,
      latitude: loc.latitude,
      longitude: loc.longitude,
      elevation: loc.elevation,
      timezone: loc.timezone,
      predicted_weather_data: loc.predicted_weather_data
    )
  end

  def farm_prediction_dto(f = @farm)
    Domain::WeatherData::Dtos::FarmWeatherPredictionDto.new(
      id: f.id,
      weather_location_id: f.weather_location_id,
      predicted_weather_data: f.predicted_weather_data
    )
  end

  def plan_weather_dto(plan)
    Domain::WeatherData::Dtos::CultivationPlanWeatherDto.new(
      id: plan.id,
      prediction_target_end_date: plan.prediction_target_end_date,
      calculated_planning_end_date: plan.calculated_planning_end_date,
      predicted_weather_data: plan.predicted_weather_data
    )
  end

  test "initialize requires clock responding to today and now" do
    bad_clock = Object.new

    error = assert_raises(ArgumentError) do
      Domain::WeatherData::Interactors::WeatherPredictionInteractor.new(
        weather_location: weather_location_dto,
        cultivation_plan_gateway: @cultivation_plan_gateway,
        farm_gateway: @farm_gateway,
        weather_data_gateway: @weather_data_gateway,
        prediction_gateway: @prediction_gateway,
        logger: @weather_prediction_logger,
        clock: bad_clock,
        anchors_resolver: @anchors_resolver
      )
    end
    assert_match(/clock/, error.message)
  end

  test "initialize requires anchors_resolver responding to anchors_for" do
    error = assert_raises(ArgumentError) do
      Domain::WeatherData::Interactors::WeatherPredictionInteractor.new(
        weather_location: weather_location_dto,
        cultivation_plan_gateway: @cultivation_plan_gateway,
        farm_gateway: @farm_gateway,
        weather_data_gateway: @weather_data_gateway,
        prediction_gateway: @prediction_gateway,
        logger: @weather_prediction_logger,
        clock: @weather_prediction_clock,
        anchors_resolver: Object.new
      )
    end
    assert_match(/anchors_resolver/, error.message)
  end

  test "initialize requires weather_location" do
    error = assert_raises(ArgumentError) do
      Domain::WeatherData::Interactors::WeatherPredictionInteractor.new(weather_location: nil, cultivation_plan_gateway: @cultivation_plan_gateway, farm_gateway: @farm_gateway, weather_data_gateway: @weather_data_gateway, prediction_gateway: @prediction_gateway, logger: @weather_prediction_logger, clock: @weather_prediction_clock, anchors_resolver: @anchors_resolver)
    end
    assert_includes error.message, "weather_location"
  end

  test "get_existing_prediction returns cached location prediction when available" do
    prediction_payload = {
      "data" => [
        { "time" => "2025-01-01", "temperature_2m_max" => 15.0, "temperature_2m_min" => 5.0, "temperature_2m_mean" => 10.0, "precipitation_sum" => 0.0 }
      ],
      "prediction_start_date" => "2025-01-01",
      "prediction_end_date" => "2025-12-31",
      "generated_at" => Time.current.iso8601,
      "predicted_at" => Time.current.iso8601,
      "target_end_date" => "2025-12-31",
      "model" => "lightgbm"
    }
    @weather_location.update!(predicted_weather_data: prediction_payload)
    @weather_location.reload

    service = Domain::WeatherData::Interactors::WeatherPredictionInteractor.new(weather_location: weather_location_dto, cultivation_plan_gateway: @cultivation_plan_gateway, farm_gateway: @farm_gateway, weather_data_gateway: @weather_data_gateway, prediction_gateway: @prediction_gateway, logger: @weather_prediction_logger, clock: @weather_prediction_clock, anchors_resolver: @anchors_resolver)
    result = service.get_existing_prediction(target_end_date: Date.new(2025, 1, 1))

    assert_not_nil result
    assert_equal prediction_payload, result[:data]
    assert_equal "2025-01-01", result[:prediction_start_date]
  end

  test "predict_for_cultivation_plan persists prediction on weather_location" do
    cultivation_plan = create(:cultivation_plan, farm: @farm, user: @user, planning_end_date: Date.new(2025, 12, 31))
    plan_field = create(:cultivation_plan_field, cultivation_plan: cultivation_plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: cultivation_plan)
    create(
      :field_cultivation,
      cultivation_plan: cultivation_plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(2025, 4, 1),
      completion_date: Date.new(2025, 10, 31)
    )

    fake_weather_info = {
      data: {
        "latitude" => @weather_location.latitude.to_f,
        "longitude" => @weather_location.longitude.to_f,
        "elevation" => @weather_location.elevation.to_f,
        "timezone" => @weather_location.timezone,
        "data" => [
          { "time" => "2025-01-01", "temperature_2m_max" => 20.0, "temperature_2m_min" => 10.0, "temperature_2m_mean" => 15.0, "precipitation_sum" => 0.0 }
        ]
      },
      prediction_start_date: "2025-01-01",
      target_end_date: cultivation_plan.prediction_target_end_date,
      prediction_days: 365
    }

    service = Domain::WeatherData::Interactors::WeatherPredictionInteractor.new(weather_location: weather_location_dto, farm: farm_prediction_dto, cultivation_plan_gateway: @cultivation_plan_gateway, farm_gateway: @farm_gateway, weather_data_gateway: @weather_data_gateway, prediction_gateway: @prediction_gateway, logger: @weather_prediction_logger, clock: @weather_prediction_clock, anchors_resolver: @anchors_resolver)

    service.stub(:prepare_weather_data, fake_weather_info) do
      service.predict_for_cultivation_plan(plan_weather: plan_weather_dto(cultivation_plan))
    end

    @weather_location.reload
    cultivar_prediction = cultivation_plan.reload.predicted_weather_data

    assert_equal @weather_location.predicted_weather_data, cultivar_prediction
    assert_equal "lightgbm", @weather_location.predicted_weather_data["model"]
    assert_equal "2025-01-01", @weather_location.predicted_weather_data["prediction_start_date"]
    assert_equal "2025-12-31", @weather_location.predicted_weather_data["target_end_date"]
  end

  test "predict_for_cultivation_plan uses prediction data when current year data is missing" do
    cultivation_plan = create(:cultivation_plan, farm: @farm, user: @user, planning_end_date: Date.new(2025, 12, 31))
    plan_field = create(:cultivation_plan_field, cultivation_plan: cultivation_plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: cultivation_plan)
    create(
      :field_cultivation,
      cultivation_plan: cultivation_plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(2025, 4, 1),
      completion_date: Date.new(2025, 10, 31)
    )

    current_year_start = Date.new(Date.current.year, 1, 1)
    current_year_end = Date.current - 2.days

    @weather_location.weather_data.where(date: current_year_start..current_year_end).delete_all

    current_year_data = @weather_location.weather_data.where(date: current_year_start..current_year_end)
    assert_empty current_year_data, "Current year data should be empty for this test"

    service = Domain::WeatherData::Interactors::WeatherPredictionInteractor.new(weather_location: weather_location_dto, farm: farm_prediction_dto, cultivation_plan_gateway: @cultivation_plan_gateway, farm_gateway: @farm_gateway, weather_data_gateway: @weather_data_gateway, prediction_gateway: @prediction_gateway, logger: @weather_prediction_logger, clock: @weather_prediction_clock, anchors_resolver: @anchors_resolver)

    fake_training_data = (1..100).map { |i| build_stubbed(:weather_datum, weather_location: @weather_location, date: Date.current - 100 + i.days, temperature_max: 20.0) }
    fake_training_result = { data: fake_training_data, end_date: fake_training_data.last.date }
    service.stub(:get_training_data, fake_training_result) do
      fake_prediction = {
        "latitude" => @weather_location.latitude.to_f,
        "longitude" => @weather_location.longitude.to_f,
        "elevation" => (@weather_location.elevation || 0.0).to_f,
        "timezone" => @weather_location.timezone,
        "data" => [
          { "time" => "2026-01-30", "temperature_2m_max" => 20.0, "temperature_2m_min" => 10.0, "temperature_2m_mean" => 15.0, "precipitation_sum" => 0.0 }
        ]
      }
      service.stub(:get_prediction_data, fake_prediction) do
        result = service.predict_for_cultivation_plan(plan_weather: plan_weather_dto(cultivation_plan))

        assert_not_nil result
        assert_not_nil result[:data]
        assert result[:data]["data"].is_a?(Array)
        assert_not_empty result[:data]["data"], "Prediction data should be used when current year data is missing"
      end
    end
  end
end
