# frozen_string_literal: true

module Adapters
  module WeatherData
    class WeatherPredictionInteractorFactory
      def initialize(
        cultivation_plan_gateway:,
        farm_gateway:,
        weather_data_gateway:,
        prediction_gateway:,
        logger:,
        clock:,
        weather_location_dto_from_active_record:,
        farm_weather_prediction_dto_from_active_record:,
        anchors_resolver_factory:
      )
        @cultivation_plan_gateway = cultivation_plan_gateway
        @farm_gateway = farm_gateway
        @weather_data_gateway = weather_data_gateway
        @prediction_gateway = prediction_gateway
        @logger = logger
        @clock = clock
        @weather_location_dto_from_active_record = weather_location_dto_from_active_record
        @farm_weather_prediction_dto_from_active_record = farm_weather_prediction_dto_from_active_record
        @anchors_resolver_factory = anchors_resolver_factory
      end

      def build(weather_location:, farm:)
        wl_dto = if weather_location.is_a?(Domain::WeatherData::Contracts::WeatherLocationPredictionInput)
          weather_location
        else
          @weather_location_dto_from_active_record.call(weather_location)
        end

        farm_dto = if farm.nil?
          nil
        elsif farm.is_a?(Domain::WeatherData::Contracts::FarmWeatherPredictionInput)
          farm
        else
          @farm_weather_prediction_dto_from_active_record.call(farm)
        end

        Domain::WeatherData::Interactors::WeatherPredictionInteractor.new(
          weather_location: wl_dto,
          farm: farm_dto,
          cultivation_plan_gateway: @cultivation_plan_gateway,
          farm_gateway: @farm_gateway,
          weather_data_gateway: @weather_data_gateway,
          prediction_gateway: @prediction_gateway,
          logger: @logger,
          clock: @clock,
          anchors_resolver: @anchors_resolver_factory.call(@clock)
        )
      end
    end
  end
end
