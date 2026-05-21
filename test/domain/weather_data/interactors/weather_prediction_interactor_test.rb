# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module WeatherData
    module Interactors
      # WeatherPredictionInteractor の純粋ユニットテスト（memory gateway 注入・Rails 非依存）。
      # 旧 test/integration/domain/... の実 AR + FactoryBot 版を ARCHITECTURE.md Testing 規約
      # （interactor は memory gateway で test/domain/ に置く）に沿って書き直したもの。
      class WeatherPredictionInteractorTest < DomainLibTestCase
        FakeClock = Struct.new(:today, :now)

        FakeDatum = Struct.new(
          :date, :temperature_max, :temperature_min, :temperature_mean,
          :precipitation, :sunshine_hours, :wind_speed, :weather_code, keyword_init: true
        )

        # anchors_resolver: 訓練窓・当年履歴・既定予測終了を返す（Rails アダプタの代替）。
        class FakeAnchorsResolver
          Anchors = Struct.new(
            :training_start_date, :training_end_date,
            :current_year_history_start_date, :current_year_history_end_date,
            :default_target_end_date, keyword_init: true
          )

          def anchors_for(_reference_calendar_day)
            Anchors.new(
              training_start_date: Date.new(2006, 1, 1),
              training_end_date: Date.new(2026, 5, 13),
              current_year_history_start_date: Date.new(2026, 1, 1),
              current_year_history_end_date: Date.new(2026, 5, 13),
              default_target_end_date: Date.new(2026, 11, 15)
            )
          end
        end

        class FakeWeatherDataGateway
          attr_reader :persisted

          def initialize(period_data: [])
            @period_data = period_data
            @persisted = nil
          end

          def weather_data_for_period(weather_location_id:, start_date:, end_date:)
            @period_data
          end

          def update_predicted_weather_data(weather_location_id:, payload:)
            @persisted = { weather_location_id: weather_location_id, payload: payload }
          end
        end

        class FakeCultivationPlanGateway
          attr_reader :updated

          def update_predicted_weather_data(plan_id, payload)
            @updated = { plan_id: plan_id, payload: payload }
          end
        end

        setup do
          @clock = FakeClock.new(Date.new(2026, 5, 15), Time.utc(2026, 5, 15, 8, 0, 0))
          @anchors_resolver = FakeAnchorsResolver.new
          @logger = CapturingLogger.new
          @weather_data_gateway = FakeWeatherDataGateway.new
          @cultivation_plan_gateway = FakeCultivationPlanGateway.new
        end

        test "initialize requires a clock responding to :today and :now" do
          error = assert_raises ArgumentError do
            build_interactor(clock: Object.new)
          end
          assert_match(/clock/, error.message)
        end

        test "initialize requires an anchors_resolver responding to :anchors_for" do
          error = assert_raises ArgumentError do
            build_interactor(anchors_resolver: Object.new)
          end
          assert_match(/anchors_resolver/, error.message)
        end

        test "initialize requires a weather_location" do
          error = assert_raises ArgumentError do
            build_interactor(weather_location: nil)
          end
          assert_includes error.message, "weather_location"
        end

        test "get_existing_prediction returns the cached location prediction when it covers the target" do
          payload = {
            "data" => [
              { "time" => "2025-01-01", "temperature_2m_max" => 15.0, "temperature_2m_min" => 5.0,
                "temperature_2m_mean" => 10.0, "precipitation_sum" => 0.0 }
            ],
            "prediction_start_date" => "2025-01-01",
            "prediction_end_date" => "2025-12-31",
            "target_end_date" => "2025-12-31",
            "model" => "lightgbm"
          }
          interactor = build_interactor(weather_location: weather_location_dto(predicted_weather_data: payload))

          result = interactor.get_existing_prediction(target_end_date: Date.new(2025, 1, 1))

          assert_not_nil result
          assert_equal payload, result[:data]
          assert_equal "2025-01-01", result[:prediction_start_date]
        end

        test "predict_for_cultivation_plan persists the built payload via both gateways" do
          interactor = build_interactor
          fake_weather_info = {
            data: {
              "latitude" => 35.0, "longitude" => 139.0, "elevation" => 0.0, "timezone" => "Asia/Tokyo",
              "data" => [
                { "time" => "2025-01-01", "temperature_2m_max" => 20.0, "temperature_2m_min" => 10.0,
                  "temperature_2m_mean" => 15.0, "precipitation_sum" => 0.0 }
              ]
            },
            prediction_start_date: "2025-01-01",
            target_end_date: Date.new(2025, 12, 31),
            prediction_days: 365
          }

          interactor.stub(:prepare_weather_data, fake_weather_info) do
            interactor.predict_for_cultivation_plan(plan_weather: plan_weather_dto)
          end

          location_payload = @weather_data_gateway.persisted[:payload]
          assert_equal "lightgbm", location_payload["model"]
          assert_equal "2025-01-01", location_payload["prediction_start_date"]
          assert_equal "2025-12-31", location_payload["target_end_date"]

          assert_equal 50, @cultivation_plan_gateway.updated[:plan_id]
          assert_equal location_payload, @cultivation_plan_gateway.updated[:payload]
        end

        test "predict_for_cultivation_plan uses prediction data when current-year data is missing" do
          interactor = build_interactor
          training_result = {
            data: [ FakeDatum.new(date: Date.new(2026, 5, 13), temperature_max: 20.0, temperature_min: 10.0,
                                  temperature_mean: 15.0, precipitation: 0.0, sunshine_hours: 5.0,
                                  wind_speed: 2.0, weather_code: 0) ],
            end_date: Date.new(2026, 5, 13)
          }
          prediction = {
            "latitude" => 35.0, "longitude" => 139.0, "elevation" => 0.0, "timezone" => "Asia/Tokyo",
            "data" => [
              { "time" => "2026-01-30", "temperature_2m_max" => 20.0, "temperature_2m_min" => 10.0,
                "temperature_2m_mean" => 15.0, "precipitation_sum" => 0.0 }
            ]
          }

          result = interactor.stub(:get_training_data, training_result) do
            interactor.stub(:get_prediction_data, prediction) do
              interactor.predict_for_cultivation_plan(plan_weather: plan_weather_dto)
            end
          end

          assert_not_nil result
          assert_instance_of Array, result[:data]["data"]
          refute_empty result[:data]["data"]
        end

        private

        def build_interactor(weather_location: :__default, clock: :__default, anchors_resolver: :__default)
          Domain::WeatherData::Interactors::WeatherPredictionInteractor.new(
            weather_location: weather_location == :__default ? weather_location_dto : weather_location,
            cultivation_plan_gateway: @cultivation_plan_gateway,
            farm_gateway: Object.new,
            weather_data_gateway: @weather_data_gateway,
            prediction_gateway: Object.new,
            logger: @logger,
            clock: clock == :__default ? @clock : clock,
            anchors_resolver: anchors_resolver == :__default ? @anchors_resolver : anchors_resolver
          )
        end

        def weather_location_dto(predicted_weather_data: nil)
          Domain::WeatherData::Dtos::WeatherLocation.new(
            id: 1,
            latitude: 35.0,
            longitude: 139.0,
            elevation: 0.0,
            timezone: "Asia/Tokyo",
            predicted_weather_data: predicted_weather_data
          )
        end

        def plan_weather_dto
          Domain::WeatherData::Dtos::CultivationPlanWeather.new(
            id: 50,
            prediction_target_end_date: Date.new(2025, 12, 31),
            calculated_planning_end_date: Date.new(2025, 12, 31),
            predicted_weather_data: nil
          )
        end
      end
    end
  end
end
