# frozen_string_literal: true

require "test_helper"

module Domain
  module ApiWeather
    module Interactors
      class ApiWeatherHistoricalInteractorTest < ActiveSupport::TestCase
        test "on_failure when location blank" do
          gw = Object.new
          received = nil
          op = Minitest::Mock.new
          op.expect(:on_failure, nil) { |f| received = f }

          ApiWeatherHistoricalInteractor.new(output_port: op, gateway: gw).call(
            location: "",
            start_date: nil,
            end_date: nil,
            days: nil,
            data_source: "noaa"
          )

          assert_equal Domain::ApiWeather::Dtos::ApiWeatherFailureDto::KIND_LOCATION_REQUIRED, received.kind
          op.verify
        end

        test "on_success when gateway returns hash" do
          payload = { "ok" => true }
          gw = Object.new
          gw.define_singleton_method(:fetch_historical_weather_data) do |**_kw|
            payload
          end

          received = nil
          op = Minitest::Mock.new
          op.expect(:on_success, nil) { |h| received = h }

          ApiWeatherHistoricalInteractor.new(output_port: op, gateway: gw).call(
            location: "35,139",
            start_date: "2020-01-01",
            end_date: "2020-01-02",
            days: nil,
            data_source: "noaa"
          )

          assert_equal payload, received
          op.verify
        end

        test "on_failure when gateway raises DaemonUnavailable" do
          gw = Object.new
          gw.define_singleton_method(:fetch_historical_weather_data) do |**_kw|
            raise Domain::ApiWeather::Errors::DaemonUnavailable
          end

          received = nil
          op = Minitest::Mock.new
          op.expect(:on_failure, nil) { |f| received = f }

          ApiWeatherHistoricalInteractor.new(output_port: op, gateway: gw).call(
            location: "35,139",
            start_date: nil,
            end_date: nil,
            days: nil,
            data_source: "noaa"
          )

          assert_equal Domain::ApiWeather::Dtos::ApiWeatherFailureDto::KIND_DAEMON_UNAVAILABLE, received.kind
          op.verify
        end
      end

      class ApiWeatherForecastInteractorTest < ActiveSupport::TestCase
        test "on_failure when gateway raises CommandFailed" do
          gw = Object.new
          gw.define_singleton_method(:fetch_forecast_weather_data) do |**_kw|
            raise Domain::ApiWeather::Errors::CommandFailed, "boom"
          end

          received = nil
          op = Minitest::Mock.new
          op.expect(:on_failure, nil) { |f| received = f }

          ApiWeatherForecastInteractor.new(output_port: op, gateway: gw).call(location: "x")

          assert_equal Domain::ApiWeather::Dtos::ApiWeatherFailureDto::KIND_COMMAND_FAILED, received.kind
          assert_equal "boom", received.message
          op.verify
        end
      end
    end
  end
end
